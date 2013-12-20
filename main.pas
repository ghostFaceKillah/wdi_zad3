program MASCHINE;

const
  MEMSIZE = 50; // how long is memory
  MEMLEN = 16;  // how deep is memory
  CHAR_OFFSET = 48;
  A_POS = 97;

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

/// Utils

function char_to_int( c : char ) : integer;
  begin 
    char_to_int := ord(c) - CHAR_OFFSET;
  end;

function a_to_one( c: char ) : integer;
  begin
    a_to_one := ord(c) - A_POS + 1;
  end;

function get_next_input_char( var i : integer; const input_string:string) : char;
  begin
    inc(i);
    if i > length(input_string) then
      get_next_input_char := 'x'
    else if input_string[i] = ')' then
        get_next_input_char := 'x'
      else
        get_next_input_char := input_string[i];
  end;

/// Parser 

function return_terminate() : action_list;
  var
    temp : action_list;
  begin
    new(temp);
    temp^.is := terminate;
    return_terminate := temp;
  end;

procedure add_to_list(const to_add:action_list; var list, temp:action_list);
  begin
   //    DBG_REPORT( 'add_to_list', to_add);
    if list = Nil then begin
      list := to_add;
      temp := to_add;
    end else begin
      temp^.next := to_add;
      temp := temp^.next;
    end;
  end;

function get_action_list(input_string:string; var read_pos:integer) : action_list;
  function get_action(c:char) : action_list;
    function new_action(const c:char; const what:action_type) : action_list;
      var
        to_add : action_list;
        arg : char;
      begin
        new(to_add);
        to_add^.is := what;
        to_add^.next := NIl;
        if ( what = scope ) then begin
          to_add^.sub_list := get_action_list(input_string, read_pos);
        end;
        if ( what = iterate) then begin
          to_add^.arg := c;
          arg := get_next_input_char(read_pos, input_string);
          to_add^.sub_list := get_action(arg);
        end;
        if ( what = null_var ) or ( what = inc_var )
            or ( what = print_var ) then begin
          arg := get_next_input_char(read_pos, input_string);
          to_add^.arg := arg;
        end;
        if ( what = add_vars ) then begin
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
    if c = 'x' then
      get_action_list := return_terminate()
    else begin
      while not(c = 'x') do begin
        next_command := get_action(c);
        add_to_list(next_command, resu, tmp);
        c := get_next_input_char(read_pos, input_string);
      end;
      get_action_list := resu;
    end;
  end;

///// opeartions

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
    if (i>=100) and (i<1000) then
      write(' ',i);
  end;

procedure show_memory_state(const memory:memory_state);
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

function get_free_space(var memory:memory_state) : integer;
  var
    k : integer;
  begin
    get_free_space := memory.first_free;
    memory.free_list[memory.first_free] := false;
    k := memory.first_free;
    while (k <= MEMSIZE) and (memory.free_list[k] <> true) do
      inc(k);
    if ( k > MEMSIZE ) then begin
      writeln('Memory overflow');
      show_memory_state(memory);
      get_free_space := MEMSIZE + 1;
    end;
    memory.first_free := k;
  end;

procedure init_mem_line(var i,j : integer; var memory : memory_state);
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

function get_field_type(const i, j : integer) : area_type;
  begin
    if (i = 0) or (j = MEMLEN) then 
      get_field_type := address
    else
      get_field_type := storage;
  end;

procedure get_next_address( var i, j : integer; var memory:memory_state );
  var oldi,oldj:integer;
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

procedure add_one_to( i, j : integer ; var memory:memory_state);
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

procedure cleaner(x,y : integer; var memory:memory_state);
  function cleanup_end():boolean;
    begin
      cleanup_end := (get_field_type(x,y) = address) and
      (get_field_type(x,y) = address) and
      (memory.area[x,y] = 0) and
      (memory.area[x,y] = 0);
    end;
  var
    tempx, tempy : integer;
  begin
    get_next_address(x,y, memory);
    while not(cleanup_end) do begin
      if memory.area[x,y] >= 1000 then begin
        tempx := x; tempy := y;
        get_next_address(tempx, tempy, memory);
        add_one_to(tempx, tempy, memory);
        memory.area[x,y] := memory.area[x,y] - 1000;
      end;
    get_next_address(x,y, memory);
    end;
  end;


procedure add_two_vars( x1, x2, y1, y2 : integer; var memory:memory_state);
  function add_two_vars_end():boolean;
    begin
      add_two_vars_end := (get_field_type(x1,y1) = address) and
      (get_field_type(x2,y2) = address) and
      (memory.area[x1,y1] = 0) and
      (memory.area[x2,y2] = 0);
    end;
  begin
    get_next_address(x1,y1, memory);
    get_next_address(x2,y2, memory);
    while not(add_two_vars_end) do begin
      if (get_field_type(x1,y1) = storage) and
      (get_field_type(x2,y2) = storage) then
        memory.area[x1,y1] := memory.area[x1,y1] + memory.area[x2,y2];
      get_next_address(x1,y1, memory);
      get_next_address(x2,y2, memory);
    end;
  end;

procedure return_to_free_pool( x,y:integer; var memory : memory_state );
  function the_end():boolean;
    begin
      the_end := (get_field_type(x,y) = address) and
                 (memory.area[x,y] = 0);
    end;
  begin
    while not(the_end()) do begin
      if get_field_type(x,y) = address then begin
        memory.free_list[memory.area[x,y]] := true;
        if memory.area[x,y] < memory.first_free then
          memory.first_free := memory.area[x,y];
      end;
      get_next_address(x,y,memory);
    end;
  end;

procedure write_num_with_zeros( i : integer );
  begin
    if (i>=0) and (i<10) then
      write('00',i);
    if (i>=10) and (i<100) then
      write('0',i);
    if (i>=100) and (i<1000) then
      write(i);
  end;

procedure write_var( x,y: integer; var memory:memory_state);
  type
    longnum = ^numpart;
    numpart = record
      num : integer;
      next : longnum;
    end;
  function the_end():boolean;
    begin
      the_end := (get_field_type(x,y) = address) and
                 (memory.area[x,y] = 0);
    end;
  var
    to_write : longnum;
    temp : longnum;
    dropped_zeros : boolean;

  begin
    if memory.area[x,y] = 0 then writeln('0')
    else begin
      to_write := nil;
      while not(the_end()) do begin
        if get_field_type(x,y) = storage then begin
          new(temp);
          temp^.num := memory.area[x,y];
          temp^.next := to_write;
          to_write := temp;
        end;
        get_next_address(x,y,memory);
      end;
      // write
      dropped_zeros := false;
      temp := to_write;   /// WHYYYYYYY ?????
      while temp <> Nil do begin
        if not(dropped_zeros) then begin
          if temp^.num <> 0 then begin
            dropped_zeros := true;
            write(temp^.num);
          end;
        end else begin
          write_num_with_zeros(temp^.num);
        end;
        temp := temp^.next;
      end;
      writeln();
    end;
  end;

procedure null_this_var( x, y : integer; var memory : memory_state );
  begin
    return_to_free_pool(x,y, memory);
    memory.area[x,y] := 0;
  end;

///// Eval

procedure eval( a : action_list; var memory:memory_state );
  var
    k : integer;
  begin
    while a <> Nil do begin
      case a^.is of
        print_mem : show_memory_state(memory);
        print_var : write_var(0, a_to_one(a^.arg), memory);
        inc_var : add_one_to( 0, a_to_one(a^.arg), memory);
        null_var : null_this_var(0, a_to_one(a^.arg), memory);
        add_vars : begin
                     add_two_vars( 0,0, a_to_one(a^.arg),
                                 a_to_one(a^.sec_arg), memory);
                     cleaner(0, a_to_one(a^.arg), memory);
                   end;
        scope : eval( a^.sub_list, memory);
        iterate : for k := 1 to char_to_int(a^.arg) do
                    eval(a^.sub_list, memory);
      end;
      a := a^.next;
    end;
  end;


///// Debugging && testing code

procedure DBG_print_list( a:action_list);
  var
    k : integer;
  begin
    while a <> NIl do begin
      if ( a^.is = iterate ) then
        for k := 1 to char_to_int(a^.arg) do DBG_print_list( a^.sub_list )
      else if ( a^.is = scope ) then
        DBG_print_list( a^.sub_list )
      else if ( a^.is = add_vars ) then
        writeln( 'add ', a^.arg, ' to ', a^.sec_arg)
      else writeln(a^.is);
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
  end;

///// Main loop

var
  to_do : action_list;
  memory : memory_state;
  input_string : string;
  k : integer;

begin
  init(memory);
  readln(input_string);
  k := 0;
  to_do := get_action_list(input_string, k);
  while to_do^.is <> terminate do begin
    eval(to_do,memory);
    // DBG_print_list(to_do);
    readln(input_string);
    k := 0;
    to_do := get_action_list(input_string, k);
  end;
end.
