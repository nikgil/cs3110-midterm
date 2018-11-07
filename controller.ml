(** Raised if [string] in parse_input fails predicate test. *)
exception InvalidInput of string

(** Menu model for game menu logic. *)
module Menu = Model.MakeMenu
(**View is for displaying text to the user. *)
module View = View.Make
(** Game model for game logic. *)
module Game = Model.MakeGame (View)

(** Simple var to hold command to quit game at any point. *)
let quit_cmd = "quit"

(**[default_condition str] is the default predicate for input parsing and 
   returns true no matter what is provided for [str]. *)
let default_condition (str:string) : bool =
  true

(**[parse_input] takes in an optional predicate [pred] and returns the 
   input string from the user if it passes the predicate (by default all strings 
   are valid). If predicate returns false then [InvalidInput] exception is 
   raised.*)
let parse_input ?pred:(pred=default_condition) (_:unit) : string =
  let input = read_line () in
  if input = quit_cmd then (
    View.print_formatted_lst "" ["Thank you for playing and goodbye"];
    exit 0;
  ) else if pred input then
    input
  else
    raise (InvalidInput input)

(** [battle hogwarts player enemy] runs through the game loop for [player] and
    [enemy] until a win or loss condition is achieved. In the case of win, the 
    player is returned to choose another opponent, but loss will end the game
    entirely. *)
let rec battle (hogwarts:Hogwarts.t) (player:State.t) (enemy:State.t) : 
  State.t =
  let p_house = State.get_house player in
  match Game.check_conditions player enemy with
  | Win -> (
      View.print_post_condition p_house 1;
      (State.level_up (State.add_defeated_enemy player (State.get_name enemy) 
                         hogwarts))
    )
  | Loss -> (
      View.print_post_condition p_house (-1);
      exit 0;
    )
  | Continue -> (
      View.print_state player;
      View.print_state enemy;

      View.print_cmd_input p_house "Enter command";
      try (
        let cmd = Command.parse (parse_input ()) in
        let new_states = Game.run_cmd hogwarts cmd player enemy in
        battle hogwarts (fst new_states) (snd new_states)
      ) with Command.Invalidcommand -> (
          View.print_formatted_lst p_house 
            ["not a command buddy.";"Type in help to get a list of commands"];
          battle hogwarts player enemy
        )
    )

(** [play_game hogwarts player] is the main game loop that initiates
    battle, and keeps track of player inputs for choosing opponent. Will keep
    recurring until a player either dies in battle or manually quits.*)
let rec play_game (hogwarts:Hogwarts.t) (player:State.t) : unit =
  let p_house = State.get_house player in (
    View.print_enemy_lst hogwarts player;
    View.print_cmd_input p_house "Enter enemy choice";

    match Menu.choose_opponent hogwarts (parse_input ()) with
    | None -> (
        View.print_formatted_lst p_house 
          ["That wasn't on the list...";
           "10/10 for effort, -5/7 for execution. Try again"];
        play_game hogwarts player
      )
    | Some enemy -> (
        View.print_enemy enemy (State.init_enemy_with_level_deck hogwarts 
                                  (Hogwarts.character_name enemy) 
                                  (Hogwarts.character_house enemy));
        View.print_cmd_input p_house "Enter Yes to confirm enemy";
        let yes_no = String.uppercase_ascii (parse_input ()) in
        let confirm = Menu.affirmation (yes_no = "Y" || yes_no = "YES") 
            hogwarts enemy in
        match confirm with
        | None -> play_game hogwarts player
        | Some enemy_state -> (
            View.print_formatted_lst p_house 
              [("You are battling with "^(Hogwarts.character_name enemy))];
            let new_state = battle hogwarts player enemy_state in
            play_game hogwarts new_state
          )
      )
  )

(** [get_name] returns the name of a person from terminal input.
    The predicate is that the name must be alphabetical (with spaces allowed) 
    only.*)
let get_name _ : string =
  View.print_formatted_lst "" 
    ["\n\nWelcome! Welcome!";
     "I lost my list of names... So remind me who are you? "];
  let reg = Str.regexp "^[A-Za-z]+[A-Za-z ]*$" in 
  let rec parse_name _ = 
    View.print_cmd_input "" "Enter your name";
    try (
      parse_input ~pred:(fun s -> Str.string_match reg s 0) ()
    ) with InvalidInput input -> (
        View.print_formatted_lst "" 
          ["Simple stuff,";
           "I wonder how you will fare in Hogwarts if you struggle at even 
           this...";
           "Try again"];
        parse_name ()
      ) in parse_name ()

(** [get_house] returns the house of a person from terminal input.
    The predicate is that the house must be one of four canon homes:
    Gryffindor, Slytherin, Ravenclaw, Hufflepuff. It is case insensitive. *)
let get_house _ : string =
  View.print_formatted_lst "" ["\n\nAlso the sorting hat is out for lunch";
                               "So you'll need to choose your own house.";
                               "As a reminder the houses are: "];
  View.print_formatted_lst "gryffindor" ["Gryffindor"];
  View.print_formatted_lst "slytherin" ["Slytherin"];
  View.print_formatted_lst "ravenclaw" ["Ravenclaw"];
  View.print_formatted_lst "hufflepuff" ["Hufflepuff"];
  let rec choose_house _ =
    View.print_cmd_input "" "Enter your house choice";
    try (
      parse_input ~pred:(fun s -> match (String.lowercase_ascii s) with
          | "gryffindor" | "slytherin" | "ravenclaw" | "hufflepuff" -> true
          | _ -> false) ()
    ) with InvalidInput input -> (
        View.print_formatted_lst "" 
          ["Not a house..."];
        choose_house ()
      ) in choose_house ()

(** [get_files] returns the player input of spell and character JSON files in a 
    tuple of (spells,charaacters) *)
let get_files (_:unit) : (string*string)=
  View.print_cmd_input "" "Enter name of spells file";
  let spells = parse_input () in
  View.print_cmd_input "" "Enter name of characters file";
  let chars = parse_input () in
  (spells,chars)

(** [init_game] is the entry point into the game. *)
let rec init_game (_:unit) =
  View.print_title ();
  View.print_formatted_lst "" ["\nInput Quit at any point to exit game"];
  let files = get_files () in
  try (
    let hogwarts = Menu.play_init (fst files) (snd files) in
    let name = get_name ()  in
    let house = get_house () in
    let player = Menu.create_player hogwarts name house in (
      View.print_house house;
      play_game hogwarts player
    )
  ) with _ -> (
      View.print_formatted_lst "gryffindor" ["Files were invalid. Try again."];
      init_game ()
    )

(**/**)
let () = init_game ()