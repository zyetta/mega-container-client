#!/bin/bash

mkdir -p .git/hooks

cat << 'EOF' > .git/hooks/pre-push
#!/bin/bash

PROTECTED_BRANCH="main"
CURRENT_BRANCH=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

if [ "$CURRENT_BRANCH" = "$PROTECTED_BRANCH" ]; then
  echo "BLOCKED: Direct push to '$PROTECTED_BRANCH' is restricted."
  echo "Please use a Pull Request."
  echo "To bypass, use: git push --no-verify"
  exit 1
fi

exit 0
EOF

chmod +x .git/hooks/pre-push

echo "Pre-push hook installed."