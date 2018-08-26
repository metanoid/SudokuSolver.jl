# Solve a sudoku puzzle in Julia

# I need the concepts of: Cell, Row, Column, and Block

mutable struct Cell 
    domain::Set
    rowid::Integer
    colid::Integer
    boxid::Integer
    index::Integer
    value
    known::Bool
    fixed::Bool
    Cell(domain, rowid, colid, index, value, known, fixed) = begin
        boxrow = ((rowid-1) ÷ 3) + 1
        boxcol = ((colid-1) ÷ 3) + 1
        boxid = boxcol + 3(boxrow - 1)
        new(domain, rowid, colid, boxid, index, value, known, fixed)
    end 
end

printcell(cell::Cell) = begin
    if length(cell.domain) == 0
        print_with_color(:red, "\u058D")
    elseif !cell.fixed
        print_with_color(:cyan, "\u0482")
    elseif cell.known
        print_with_color(:green, cell.value, bold = true)
    else
        print_with_color(:yellow, cell.value)
    end
end

puzzle = [
    8 0 0 0 0 0 0 0 0;
    0 0 3 6 0 0 0 0 0;
    0 7 0 0 9 0 2 0 0;
    0 5 0 0 0 7 0 0 0;
    0 0 0 0 4 5 7 0 0;
    0 0 0 1 0 0 0 3 0;
    0 0 1 0 0 0 0 6 8;
    0 0 8 5 0 0 0 1 0;
    0 9 0 0 0 0 4 0 0
];

struct Sudoku
    rows::Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}
    columns::Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}
    boxes::Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}
    Sudoku(puzz) = begin
        rows = Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}(i => Dict{Tuple{Integer, Integer}, Cell}() for i ∈ 1:9)
        columns = Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}(i => Dict{Tuple{Integer, Integer}, Cell}() for i ∈ 1:9)
        boxes = Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}(i => Dict{Tuple{Integer, Integer}, Cell}() for i ∈ 1:9)
        linearindex = 1;                                               
        for (i, val) ∈ enumerate(IndexCartesian(), puzzle)
            row = i[1];
            col = i[2];
            if val == 0
                domain = Set(1:9);
                value = nothing;
                known = false;
                fixed = false;
            else
                domain = Set(val);
                value = val;
                known = true;
                fixed = true;
            end
            a = Cell(domain, row, col, linearindex, value, known, fixed);
            push!(rows[row], (row, col) => a);
            push!(columns[col], (row, col) => a);
            push!(boxes[a.boxid], (row, col) => a);
            linearindex += 1;
        end
        new(rows, columns, boxes)
    end
end

Base.show(io::IO, s::Sudoku) = begin
    horiz = "—"^24
    for r ∈ 1:9
        row = s.rows[r]
        if mod(r,3) == 1
            println(horiz)
        end
        for c ∈ 1:9
            cell = s.rows[r][(r,c)]
            if mod(c,3) == 1
                print("| ")
            end
            printcell(cell)
            print(" ")
        end
        print("|\n")
    end
    println(horiz)
end

# sudoku = Dict{String, Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}}(
#     "rows" => Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}(i => Dict{Tuple{Integer, Integer}, Cell}() for i ∈ 1:9),
#     "columns" => Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}(i => Dict{Tuple{Integer, Integer}, Cell}() for i ∈ 1:9),
#     "boxes" => Dict{Integer, Dict{Tuple{Integer, Integer}, Cell}}(i => Dict{Tuple{Integer, Integer}, Cell}() for i ∈ 1:9));

# linearindex = 1;                                               
# for (i, val) ∈ enumerate(IndexCartesian(), puzzle)
#     row = i[1];
#     col = i[2];
#     if val == 0
#         domain = Set(1:9);
#         value = nothing;
#     else
#         domain = Set(val);
#         value = val;
#     end
#     a = Cell(domain, row, col, linearindex, value);
#     push!(sudoku["rows"][row], (row, col) => a);
#     push!(sudoku["columns"][col], (row, col) => a);
#     push!(sudoku["boxes"][a.boxid], (row, col) => a);
#     linearindex += 1;
# end

update = function(state::Sudoku)
    # for each row, column, and box, remove the fixed values from the domains of all cells
    # for any domain of length 1, set the value to that element
    # if any domain is empty, return an empty array
    # otherwise return an array containing a new puzzle
    s = deepcopy(state); # make a copy so that we can freely change it
    for view ∈ [s.rows, s.columns, s.boxes];
        # viewkey is "rows", "columns", or "boxes"
        # view is a dictionary of a dict of cells (row, (row, col))
        for (bunch, my_dict) ∈ view;
            for (cellkey, cell) ∈ my_dict;
                if length(cell.domain) == 1
                    cell.value = getindex(collect(cell.domain),1); # assign the value if not already done
                    cell.fixed = true;
                    for (j_key, j_cell) ∈ my_dict;
                        if cell.index != j_cell.index;
                             delete!(j_cell.domain, cell.value); # remove a known value from other domains if not already done
                        end
                    end
                end
            end
        end
    end
    return s; # return the updated state,wrapped in an array
end;

check = function(state)
    for view ∈ [state.rows, state.columns, state.boxes];
        # viewkey is "rows", "columns", or "boxes"
        # view is a dictionary of a dict of cells (row, (row, col))
        for (bunch, my_dict) ∈ view;
            for (cellkey, cell) ∈ my_dict;
                if length(cell.domain) == 0
                    return false;
                end
            end
        end
    end
    return true    
end;

# see https://github.com/JuliaLang/julia/issues/14672 - fix implemented from v0.7.0 onwards
# Base.isless(p::Pair, q::Pair) =
#            ifelse(!isequal(p.second,q.second),
#                isless(p.second,q.second),
#                isless(p.first,q.first)
#            );

function hypothesise(state; strategy = "smallest_domains_first", verboselevel = 0)
    # given a puzzle ste, use the given strategy to identify a cell.
    # for every possible value of that cell, create a new puzzle with that value filled in
    states = Array{Sudoku,1}(); # array of all new states after hypothesis
    updated_state = update(state)
    if !check(updated_state)
        if verboselevel > 0
            println("I reached an invalid state!")
            print(updated_state)
        end
        return states
    end
    
    # get the lengths of all cell domains
    # arbitrarily iterate by rows
    domain_lengths = Dict{Tuple{Int, Int, Int, Int}, Int}();
    for (bunch, my_dict) ∈ updated_state.rows
        for (cellkey, cell) ∈ my_dict
            domain_lengths[(cell.rowid, cell.colid, cell.boxid, cell.index)] = length(cell.domain);
        end
    end
    if any(i -> i[2] == 0, domain_lengths)
        # then no valid solution is possible
        return states
    elseif all(i -> i[2] == 1, domain_lengths)
        #then we are at a unique solution
        if verboselevel > 0
            println("Found a solution!")
            print(updated_state);
        end
        push!(states, updated_state);
        return states
    else
        # the puzzle may still have at least one solution
        multi_domains = filter((k,v) -> v > 1, domain_lengths); # get the cell indices for cells with free domains
        if length(multi_domains) == 0
            #should never get here
            #println(multi_domains)
            println(domain_lengths);
            println(values(domain_lengths));
            print(updated_state)
            error("How did we get here???");
            push!(states, updated_state);
            return states;
        end
        if strategy == "smallest_domains_first"
            chosen_cell_id = minimum(multi_domains);
        elseif strategy == "largest_domains_first"
            chosen_cell_id = maximum(multi_domains);
        elseif strategy == "random_cell_order"
            chosen_cell_id = rand(multi_domains);
        else
            error("Bad spelling of strategy name");
        end
        
        chosen_cell = updated_state.rows[chosen_cell_id[1][1]][(chosen_cell_id[1][1], chosen_cell_id[1][2])];
        chosen_row = chosen_cell.rowid;
        chosen_col = chosen_cell.colid;
        chosen_box = chosen_cell.boxid;
        chosen_index = chosen_cell.index;
        for poss ∈ chosen_cell.domain
            # create a copy of the current state
            new_state = deepcopy(updated_state);
            # update the chosen cell to the chosen possibility
            new_cell = Cell(Set(poss), chosen_row, chosen_col, chosen_index, poss, false, true);
            push!(new_state.rows[chosen_row], (chosen_row, chosen_col) => new_cell);
            push!(new_state.columns[chosen_col], (chosen_row, chosen_col) => new_cell);
            push!(new_state.boxes[chosen_box], (chosen_row, chosen_col) => new_cell);
            if verboselevel > 0
                println("Trying a new hypothesis:")
                print(new_state)
            end
            new_states = update(new_state);
            if check(new_states)
                # then not yet invalid
                my_solutions = hypothesise(new_states; strategy = strategy, verboselevel = verboselevel - 1);
                if length(my_solutions) > 0
                    append!(states, my_solutions)
                end
            end
        end
    end
    return states
end;
#n = check(sudoku);

#using Gallium
p = Sudoku(puzzle);
println("Received sudoku:")
print(p)
println("Ready to solve!")
a = hypothesise(p);
for i ∈ a   
    print(i, "\n");
end
