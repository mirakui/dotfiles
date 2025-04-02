IRB.conf[:COMMAND_ALIASES] = {
  :"$" => :show_source,
  :"@" => :whereami,
  n: :irb_next, 
  s: :irb_step, 
  c: :irb_continue,
}

