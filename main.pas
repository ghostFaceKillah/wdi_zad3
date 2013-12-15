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

function char_to_int( c : char ) : integer;
  begin 
    char_to_int := ord(c) - CHAR_OFFSET;
  end;

function a_to_one( c: char ) : integer;
  begin
    a_to_one := ord(c) - A_POS + 1;
  end;

////////////////////// Parser ///////////////////////

function is_command_end(c:char) : boolean;
  begin
    is_command_end := false;
    if ord(c) = 10 then is_command_end := true; 
      // line feed char works for unix-ish OSes and MS WIN
    if ord(c) = 13 then is_command_end := true;
      // carriage return works for mac 
    if ord(c) = 41 then is_command_end := true;
      // we need this for correct parsing of scopes
  end;

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
    if list = Nil then begin
      list := to_add;
      temp := to_add;
    end else begin
      temp^.next := to_add;
      temp := temp^.next;
    end;
  end;

function get_action_list() : action_list;
  function get_action(c:char) : action_list;
    function new_action(const c:char; const what:action_type) : action_list;
      var
        to_add : action_list;
        arg : char;
      begin
        new(to_add);
        to_add^.is := what;
        to_add^.next := NIl;
        if ( what = scope ) then
          to_add^.sub_list := get_action_list();
        if ( what = iterate) then begin
          to_add^.arg := c;
          read(arg);
          to_add^.sub_list := get_action(arg);
        end;
        if ( what = null_var ) or ( what = inc_var )
            or ( what = print_var ) then begin
          read(arg);
          to_add^.arg := arg;
        end;
        if ( what = add_vars ) then begin
          read(arg);
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
    read(c);
    if is_command_end(c) then
      get_action_list := return_terminate()
    else begin
      while not(is_command_end(c)) do begin
        next_command := get_action(c);
        add_to_list(next_command, resu, tmp);
        read(c);
      end;
      get_action_list := resu;
    end;
  end;

/////////////////////// opeartions  /////////////////////////////

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
    k := memory.first_free;
    while (memory.free_list [k] <> true) and (k <= MEMLEN) do 
      inc(k);
    if ( k > MEMLEN ) then begin
      writeln('Memory overflow');
      get_free_space := MEMSIZE + 1;
    end else
      memory.first_free := k;
  end;

procedure init_mem_line(const i : integer; var memory : memory_state);
  var
    k : integer;
  begin
    for k := 1 to MEMLEN do 
      memory.area[i, k] := 0;
  end;

function get_field_type(const i, j : integer) : area_type;
  begin
    if (i = 0) or (j = MEMLEN) then 
      get_field_type := address
    else
      get_field_type := storage;
  end;

procedure get_next_address( var i, j : integer; var memory:memory_state );
  var
    k : integer;
  begin 
    if get_field_type(i,j) = storage then
      inc(j)
    else begin
      if memory.area[i,j] = 0 then begin
        k := get_free_space(memory);
        init_mem_line(k, memory);
        memory.free_list[k] := false; // move to init_mem_line
        memory.area[i,j] := k;
        i := k;
        j := 1;
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

procedure add_two_vars( x1, x2, y1, y2 : integer; var memory:memory_state);
  begin
    while not( get_field_type
  end;

//////////////////////// Debugging && testing code /////////////////////
procedure DBG_print_list( a:action_list);
  var
    k : integer;
  begin
    while a <> NIl do begin
      if ( a^.is = iterate ) then
        for k := 1 to char_to_int(a^.arg) do DBG_print_list( a^.sub_list )
      else if ( a^.is = scope ) then
        DBG_print_list( a^.sub_list )
      else writeln(a^.is);
      a := a^.next;
    end;
  end;

//////////////////////// Main loop ////////////////////////////////////

var
  to_do : action_list;
  memory : memory_state;
  i : longint;

begin
  init(memory);
  add_one_to(0, a_to_one('a'), memory);
  show_memory_state(memory);
  to_do := get_action_list();
  DBG_print_list(to_do);
end.
