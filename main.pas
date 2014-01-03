program MASCHINE;

// this machine works as follows:
// initiate(state of machine)
// parser(input) -> list of actions  --> eval(list of actions, state of memory) 
//                      in order by using operations(state of memory) --> output
//
// parser - it parses inputs from stdin into list of actions to be evaled 
// operations - are later called by eval to manipulate state of the machine
// eval - takes list of actions and calls commands to manipulate state of machine 
//        as requested by user via commands

const
  MEMSIZE = 50;     // how long is memory
  MEMLEN = 16;      // how deep is memory
  CHAR_OFFSET = 48; // for casting char to int
  A_POS = 97;       // for getting maping 'a' -> 1; b -> '2' etc
  EOL_CHAR = 'x';   // just a char to serve as eol in this code

type
  action_type = (print_mem, print_var, inc_var, null_var,
                 add_vars, scope, iterate, terminate);
  action_list = ^action;
  action = record
    is : action_type;
    arg : char;
    sec_arg : char;
    sub_list : action_list;
    next : action_list;
  end;
  memory_state = record
    area : array[0..MEMSIZE, 1..MEMLEN] of integer;
    free_list : array [1..MEMSIZE] of boolean;
    first_free : integer;
  end;
  area_type = (storage, address);

/////////////////////////////     Utils     ///////////////////////////////////

function char_to_int(c : char) : integer;
  begin 
    char_to_int := ord(c) - CHAR_OFFSET;
  end;

function where_stored(c: char) : integer; 
// it transforms letters 'a' to 'p' into 1 to 16
  begin
    where_stored := ord(c) - A_POS + 1;
  end;

function get_next_input_char(var i : integer; const input_string:string) : char;
  begin
    inc(i);
    if i > length(input_string) then
      get_next_input_char := EOL_CHAR
    else if input_string[i] = ')' then
        get_next_input_char := EOL_CHAR
      else
        get_next_input_char := input_string[i];
  end;

////////////////////////     Parsing system     ///////////////////////////////

procedure add_to_list(const to_add:action_list; var list, temp:action_list);
  begin
    if list = Nil then begin
      list := to_add;
      temp := to_add;
    end else begin
      temp^.next := to_add;
      temp := temp^.next;
    end;
  end;

// paradoxally, function below is triple nested for readability
//
// new_action is a ''constructor'' for type action_list and just wraps arguments
// into an ''action'' that is added to the list to be later evaled
//
// get_action is enumeration of all possible actions to get from input, which calls
// new_action with right arguments and returns action object it got from new_action
//
// get_action_list reads inputs, calls get_action and constructs list of commnads 
// returned by it, which is later evaled by eval part of the code
//
// please note, that we need triple nesting in order to enable recursive call of
// get_action_list in new_action - it allows us to use same parsing for commands
// in parenthesis (scopes and iterators)

function get_action_list(input_string:string; var read_pos:integer) : action_list;
  function get_action(c:char) : action_list;
    function new_action(const c:char; const what:action_type) : action_list;
      var
        to_add : action_list;
        arg : char;
      begin
        new(to_add);
        to_add^.is := what;
        to_add^.next := nil;
        if (what = scope) then begin
          to_add^.sub_list := get_action_list(input_string, read_pos);
        end;
        if (what = iterate) then begin
          to_add^.arg := c;
          arg := get_next_input_char(read_pos, input_string);
          to_add^.sub_list := get_action(arg);
        end;
        if (what = null_var) or (what = inc_var) or (what = print_var)
           then begin
          arg := get_next_input_char(read_pos, input_string);
          to_add^.arg := arg;
        end;
        if (what = add_vars) then begin
          to_add^.arg := c;
          arg := get_next_input_char(read_pos, input_string);
          to_add^.sec_arg := arg;
        end;
        new_action := to_add;
    end;

    begin
      if c = '#' then
        get_action := new_action(c, print_mem);
      if c = '@' then
        get_action := new_action(c, print_var);
      if c = '^' then
        get_action := new_action(c, inc_var);
      if c = '\' then
        get_action := new_action(c, null_var);
      if (ord(c) >= 97) and (ord(c) <= 112) then // a - p
        get_action := new_action(c, add_vars);
      if c = '(' then
        get_action := new_action(c, scope);
      if (ord(c) >= 50) and (ord(c) <= 57) then // 2 - 9
        get_action := new_action(c, iterate);
    end;

  var
    c : char;
    resu, tmp : action_list;
    next_command : action_list;

  begin
    resu := Nil; tmp := Nil;
    c := get_next_input_char(read_pos, input_string);
    if c = EOL_CHAR then
      get_action_list := Nil     //  terminate scope or whole program
    else begin
      while not(c = EOL_CHAR) do begin
        next_command := get_action(c);
        add_to_list(next_command, resu, tmp);
        c := get_next_input_char(read_pos, input_string);
      end;
      get_action_list := resu;
    end;
  end;

//////////////////////  Operations on memory state  ///////////////////////////

procedure init(var memory:memory_state);
  var
    i, j : integer;
  begin
    for i := 0 to MEMSIZE do
      for j := 1 to MEMLEN do 
        memory.area[i,j] := 0;
    for i := 1 to MEMSIZE do 
      memory.free_list[i] := true;
    memory.first_free := 1;
  end;

procedure write_num(i : integer);
  begin
    if (i>=0) and (i<10) then
      write('   ',i);
    if (i>=10) and (i<100) then
      write('  ',i);
    if (i>=100) then
      write(' ',i);
  end;

procedure show_memory_state(const memory : memory_state);
  var
    i, j : integer;
  begin
    for i := 0 to 9 do begin
      write(' ',i,':');
      for j := 1 to MEMLEN do
        write_num(memory.area[i,j]);
      writeln();
    end;
    for i := 10 to MEMSIZE do begin
      write(i,':');
      for j := 1 to MEMLEN do
        write_num(memory.area[i,j]);
      writeln();
    end;
  end;

function get_free_space(var memory : memory_state) : integer;
  var
    k : integer;
  begin
    if memory.first_free <= MEMSIZE then begin
      get_free_space := memory.first_free;
      memory.free_list[memory.first_free] := false;
      k := memory.first_free;
      while (k <= MEMSIZE) and (memory.free_list[k] <> true) do
        inc(k);
      memory.first_free := k;
    end else begin
      writeln('Memory overflow');
      writeln('Dumping memory allocation state:');
      show_memory_state(memory);
      get_free_space := MEMSIZE + 1;
    end;
  end;

procedure init_mem_line(var i,j : integer; var memory : memory_state);
// initialize a line of memory by nulling it - there can be leftovers 
  var
    k : integer;
  begin
    k := get_free_space(memory);
    memory.area[i,j] := k;
    i := k;
    for k := 1 to MEMLEN do 
      memory.area[i, k] := 0;
    j := 1;
  end;

function get_field_type(const i,j : integer) : area_type;
  begin
    if (i = 0) or (j = MEMLEN) then 
      get_field_type := address
    else
      get_field_type := storage;
  end;

procedure get_next_address(var i,j : integer; var memory : memory_state);
  var oldi,oldj : integer;
  begin 
    if get_field_type(i,j) = storage then
      inc(j)
    else begin
      if memory.area[i,j] = 0 then begin
        oldi := i; oldj := j;
        init_mem_line(i,j,memory);
        memory.area[oldi, oldj] := i;
      end else begin
        i := memory.area[i,j];
        j := 1;
      end;
    end;
  end;

procedure add_one_to(i,j : integer ; var memory:memory_state);
  begin
    if get_field_type(i,j) = address then
      get_next_address(i,j, memory);
    inc(memory.area[i,j]);
    if memory.area[i,j] = 1000 then begin
      memory.area[i,j] := 0;
      get_next_address(i,j, memory);
      add_one_to(i,j, memory);
    end;
  end;

function the_end(x,y : integer; const memory:memory_state) : boolean;
  begin
    the_end := (get_field_type(x,y) = address) and
    (memory.area[x,y] = 0);
  end;

procedure cleaner(x,y : integer; var memory : memory_state);
  // handles overflowed (val > 1000) bytes after adding two vars
  // and makes adding two vars so much easier
  var
    tempx, tempy : integer;
  begin
    if memory.area[x,y] <> 0 then begin
      get_next_address(x,y, memory);
      while not(the_end(x,y,memory)) do begin
        if memory.area[x,y] >= 1000 then begin
          tempx := x; tempy := y;
          get_next_address(tempx, tempy, memory);
          add_one_to(tempx, tempy, memory);
          memory.area[x,y] := memory.area[x,y] - 1000;
        end;
      get_next_address(x,y, memory);
      end;
    end;
  end;

procedure add_two_vars(x1,x2,y1,y2 : integer; var memory:memory_state);
  begin
    if memory.area[x2,y2] <> 0 then begin 
      repeat
        begin
          get_next_address(x1,y1, memory);
          get_next_address(x2,y2, memory);
          if (get_field_type(x1,y1) = storage) and
          (get_field_type(x2,y2) = storage) then
            memory.area[x1,y1] := memory.area[x1,y1] + memory.area[x2,y2];
        end
      until the_end(x2, y2, memory);
    end;
  end;

procedure return_to_free_pool(x,y:integer; var memory : memory_state);
  begin
    while not(the_end(x, y, memory)) do begin
      if get_field_type(x,y) = address then begin
        memory.free_list[memory.area[x,y]] := true;
        if memory.area[x,y] < memory.first_free then
          memory.first_free := memory.area[x,y];
      end;
      get_next_address(x,y,memory);
    end;
  end;

procedure write_num_with_zeros(i : integer);
  begin
    if (i>=0) and (i<10) then
      write('00',i);
    if (i>=10) and (i<100) then
      write('0',i);
    if (i>=100) and (i<1000) then
      write(i);
  end;

procedure print_this_var(x,y: integer; var memory:memory_state);
  // uses a small stack to list all bytes of a var to print
  type
    longnum = ^numpart;
    numpart = record
      num : integer;
      next : longnum;
    end;
  var
    to_write : longnum;
    trash : longnum;
    temp : longnum;
    dropped_zeros : boolean;
  begin
    if memory.area[x,y] = 0 then writeln('0')
    else begin
      // build the stack ...
      to_write := nil;
      while not(the_end(x,y,memory)) do begin
        if get_field_type(x,y) = storage then begin
          new(temp);
          temp^.num := memory.area[x,y];
          temp^.next := to_write;
          to_write := temp;
        end;
        get_next_address(x,y,memory);
      end;
      // ... and write
      dropped_zeros := false;
      temp := to_write;
      while temp <> Nil do begin
        if not(dropped_zeros) then begin
          if temp^.num <> 0 then begin
            dropped_zeros := true;
            write(temp^.num);
          end;
        end else begin
          write_num_with_zeros(temp^.num);
        end;
        trash := temp;
        temp := temp^.next;
        dispose(trash);
      end;
      writeln();
    end;
  end;

procedure null_this_var(x,y : integer; var memory : memory_state);
  begin
    return_to_free_pool(x,y, memory);
    memory.area[x,y] := 0;
  end;

/////////////////////////////     Eval     ////////////////////////////////////

procedure eval(a : action_list; var memory:memory_state);
  var
    k : integer;
  begin
    while a <> Nil do begin
      case a^.is of
        print_mem : show_memory_state(memory);
        print_var : print_this_var(0, where_stored(a^.arg), memory);
        inc_var   : add_one_to( 0, where_stored(a^.arg), memory);
        null_var  : null_this_var(0, where_stored(a^.arg), memory);
        add_vars  : begin
                     add_two_vars( 0,0, where_stored(a^.arg),
                                 where_stored(a^.sec_arg), memory);
                     cleaner(0, where_stored(a^.arg), memory);
                    end;
        scope     : eval( a^.sub_list, memory);
        iterate   : for k := 1 to char_to_int(a^.arg) do
                      eval(a^.sub_list, memory);
                    else;
      end;
      a := a^.next;
    end;
  end;

procedure free_mem(arg : action_list);
  var
    trash : action_list;
  begin
    while arg<>Nil do begin
      trash := arg;
      arg := arg^.next;
      dispose(trash);
    end;
  end;

////////////////////// Debugging && testing code /////////////////////////////

procedure DBG_print_list( a:action_list);
  begin
    while a <> Nil do begin
      case a^.is of
        print_mem : writeln('print memory');
        print_var : writeln('print variable ', a^.arg);
        inc_var   : writeln('increment variable ', a^.arg);
        null_var  : writeln ('null variable', a^.arg);
        add_vars  : writeln('add variable ', a^.arg, ' to ', a^.sec_arg);
        scope     : begin
                      writeln('### beginning writing scope '); 
                      DBG_print_list(a^.sub_list);
                      writeln('### scope end ');
                    end;
        iterate   : begin
                      writeln();
                      writeln('%%% iterate scope ', a^.arg, ' times'); 
                      DBG_print_list(a^.sub_list);
                      writeln('%%% iterate end ');
                      writeln();
                    end;
      end;
      a := a^.next;
    end;
  end;

procedure DBG_print_malloc(const mem:memory_state);
  var
    k : integer;
  begin
    writeln();
    writeln('used memory areas:');
    for k := 1 to MEMSIZE do 
      if not(mem.free_list[k]) then
        write(k,' ');
    writeln();
    writeln('The first free is :', mem.first_free);
  end;

/////////////////////////////  Main loop  /////////////////////////////////////

var
  to_do : action_list;
  memory : memory_state;
  input_string : string;
  read_pos : integer; 

begin
  init(memory);
  readln(input_string);
  read_pos := 0;
  to_do := get_action_list(input_string, read_pos);
  while to_do <> Nil do begin
    eval(to_do,memory);
    free_mem(to_do);
    readln(input_string);
    read_pos := 0;
    to_do := get_action_list(input_string, read_pos);
  end;
end.
