function mdcd --description "makes and changes to a dir"
  if test (count $argv) = 0
    return
  end
  mkdir -p $argv[1]
  cd $argv[1]
end
