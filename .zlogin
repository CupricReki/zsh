
# Add any zlogin local configruations
for file in $HOME/.zsh/zlogin_local/*; do
  source "$file"
done


# Add any zlogin configruations
for file in $HOME/.zsh/zlogin/*; do
  source "$file"
done

