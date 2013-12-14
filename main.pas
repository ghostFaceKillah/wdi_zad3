program MASCHINE;

const
  MEMSIZE = 50; // how long is memory
  MEMLEN = 15;  // how deep is memory
  CHAR_OFFSET = 48;

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
  memory_array = array[0..MEMSIZE, 0..MEMLEN] of shortint;

function char_to_int( c : char ) : integer;
  begin 
    char_to_int := ord(c) - CHAR_OFFSET;
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

function parse() : action_list;
  function get_next_command(c:char) : action_list;
    function new_action( const c : char; const what : action_type ) : action_list;
      var
        to_add : action_list;
        arg : char;
      begin
        new(to_add);
        to_add^.is := what;
        to_add^.next := NIl;
        if ( what = scope ) then
          to_add^.sub_list := parse();
        if ( what = iterate) then begin
          to_add^.arg := c;
          read(arg);
          to_add^.sub_list := get_next_command(arg);
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
        get_next_command := new_action(c, print_mem);
      if c = '@' then
        get_next_command := new_action(c, print_var);
      if c = '^' then
        get_next_command := new_action(c, inc_var);
      if c = '\' then
        get_next_command := new_action(c, null_var);
      if (ord(c) >= 97) and (ord(c) <= 112) then // a - p
        get_next_command := new_action(c, add_vars);
      if c = '(' then
        get_next_command := new_action(c, scope);
      if (ord(c) >= 50) and (ord(c) <= 57) then // 2 - 9
        get_next_command := new_action(c, iterate);
    end;
  var
    c : char;
    resu, tmp : action_list;
    next_command : action_list;
  begin
    resu := Nil; tmp := Nil;
    read(c);
    if is_command_end(c) then
      parse := return_terminate()
    else begin
      while not(is_command_end(c)) do begin
        next_command := get_next_command(c);
        add_to_list(next_command, resu, tmp);
        read(c);
      end;
      parse := resu;
    end;
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

begin
  to_do := parse();
  DBG_print_list(to_do);
end.
