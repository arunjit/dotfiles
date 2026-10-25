function vim --wraps=nvim --description 'alias vim=nvim'
  if type -q nvim
    nvim $argv
  else if type -q hx
    hx $argv
  else if type -q vim
    command vim $argv
  else
    vi $argv
  end
end
