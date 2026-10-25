function ll --description "long listing"
  if type -q eza
    eza -laUF --time-style='+%Y-%m-%d %H:%M' $argv
  else
    ls -la $argv
  end
end
