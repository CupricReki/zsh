# Add any files to be sourced at login shell
for file in .zlogin/*; do
  source "$file"
done

# Add any local files to be sourced at login shell
for file in .zlogin_local/*; do
  source "$file"
done

