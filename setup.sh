#!/bin/bash
# gitmeright setup script
# author: @s403o

echo "🎉 Welcome to gitmeright setup!"

# Step 1: User Input
read -p "🔧 Enter your GitHub username: " GITHUB_USER
read -p "👤 Enter your full name for Personal (GitHub): " NAME_PERSONAL
read -p "📧 Enter email for Personal: " EMAIL_PERSONAL

read -p "🔧 Enter name for Project 1 (e.g., work): " PROJECT1
read -p "👤 Enter your full name for $PROJECT1: " NAME_PROJECT1
read -p "📧 Enter email for $PROJECT1: " EMAIL_PROJECT1

read -p "🔧 Enter name for Project 2 (e.g., freelance): " PROJECT2
read -p "👤 Enter your full name for $PROJECT2: " NAME_PROJECT2
read -p "📧 Enter email for $PROJECT2: " EMAIL_PROJECT2

# Step 2: Copy main .gitconfig
echo "📁 Copying .gitconfig to ~/.gitconfig..."
cp .gitconfig ~/.gitconfig

# Replace placeholders in ~/.gitconfig
sed -i.bak "s/GITHUB_USERNAME_PLACEHOLDER/$GITHUB_USER/" ~/.gitconfig
sed -i.bak "s/.gitconfig-personal/.gitconfig-personal/" ~/.gitconfig
sed -i.bak "s/project1/$PROJECT1/" ~/.gitconfig
sed -i.bak "s/project2/$PROJECT2/" ~/.gitconfig
rm ~/.gitconfig.bak

# Step 3: Copy project-specific configs
cp .gitconfig-personal ~/.gitconfig-personal
cp .gitconfig-project1 ~/.gitconfig-$PROJECT1
cp .gitconfig-project2 ~/.gitconfig-$PROJECT2

# Step 4: Fill in user.name, user.email, sshCommand

# Personal
sed -i "s/PERSONAL_NAME_PLACEHOLDER/$NAME_PERSONAL/" ~/.gitconfig-personal
sed -i "s/you@personal.com/$EMAIL_PERSONAL/" ~/.gitconfig-personal
sed -i "s/id_rsa_personal/id_rsa_personal/" ~/.gitconfig-personal

# Project 1
sed -i "s/PROJECT1_NAME_PLACEHOLDER/$NAME_PROJECT1/" ~/.gitconfig-$PROJECT1
sed -i "s/you@project1.com/$EMAIL_PROJECT1/" ~/.gitconfig-$PROJECT1
sed -i "s/id_rsa_project1/id_rsa_$PROJECT1/" ~/.gitconfig-$PROJECT1

# Project 2
sed -i "s/PROJECT2_NAME_PLACEHOLDER/$NAME_PROJECT2/" ~/.gitconfig-$PROJECT2
sed -i "s/you@project2.com/$EMAIL_PROJECT2/" ~/.gitconfig-$PROJECT2
sed -i "s/id_rsa_project2/id_rsa_$PROJECT2/" ~/.gitconfig-$PROJECT2

# Step 5: Generate SSH keys if missing
generate_ssh_key() {
  local keyname=$1
  local email=$2

  if [ ! -f "$HOME/.ssh/$keyname" ]; then
    echo "🔐 Generating SSH key: $keyname"
    ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/$keyname" -N ""
  else
    echo "✅ SSH key $keyname already exists. Skipping."
  fi
}

mkdir -p ~/.ssh

generate_ssh_key "id_rsa_personal" "$EMAIL_PERSONAL"
generate_ssh_key "id_rsa_$PROJECT1" "$EMAIL_PROJECT1"
generate_ssh_key "id_rsa_$PROJECT2" "$EMAIL_PROJECT2"

# Step 6: Add SSH keys to agent
echo "🚀 Adding keys to SSH agent..."
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_personal
ssh-add ~/.ssh/id_rsa_$PROJECT1
ssh-add ~/.ssh/id_rsa_$PROJECT2

# Step 7: Done!
echo ""
echo "✅ Setup complete! Git identities are now managed by gitmeright 🔥"
echo ""
echo "Test it with:"
echo "   git config user.name"
echo "   git config user.email"
echo ""
echo "💡 Tip: Use 'git config --list --show-origin' to see where Git gets its config."
