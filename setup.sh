#!/bin/bash
# gitmeright setup script
# author: @s403o

echo "🎉 Welcome to gitmeright setup!"

# Step 1: Get user input
read -p "🔧 Enter name for Project 1 (e.g., work): " PROJECT1
read -p "👤 Enter your full name for $PROJECT1: " NAME_PROJECT1
read -p "📧 Enter email for $PROJECT1 (e.g., you@work.com): " EMAIL_PROJECT1

read -p "🔧 Enter name for Project 2 (e.g., freelance): " PROJECT2
read -p "👤 Enter your full name for $PROJECT2: " NAME_PROJECT2
read -p "📧 Enter email for $PROJECT2 (e.g., you@freelance.com): " EMAIL_PROJECT2

read -p "👤 Enter your full name for Personal (GitHub): " NAME_PERSONAL
read -p "📧 Enter email for Personal (e.g., you@gmail.com): " EMAIL_PERSONAL

# Step 2: Copy .gitconfig and replace placeholders
echo "📁 Setting up main .gitconfig..."

cp .gitconfig ~/.gitconfig

sed -i.bak "s/project1/$PROJECT1/g" ~/.gitconfig
sed -i.bak "s/project2/$PROJECT2/g" ~/.gitconfig
rm ~/.gitconfig.bak

# Step 3: Prepare per-project config templates
echo "📁 Creating project-specific configs..."

cp .gitconfig-project1 ~/.gitconfig-$PROJECT1
cp .gitconfig-project2 ~/.gitconfig-$PROJECT2
cp .gitconfig-personal ~/.gitconfig-personal

# Step 4: Fill in values in each config

# Personal
sed -i "s/Your Personal Name/$NAME_PERSONAL/" ~/.gitconfig-personal
sed -i "s/you@personal.com/$EMAIL_PERSONAL/" ~/.gitconfig-personal
sed -i "s/id_rsa_personal/id_rsa_personal/" ~/.gitconfig-personal

# Project 1
sed -i "s/Your Project1 Name/$NAME_PROJECT1/" ~/.gitconfig-$PROJECT1
sed -i "s/you@project1.com/$EMAIL_PROJECT1/" ~/.gitconfig-$PROJECT1
sed -i "s/id_rsa_project1/id_rsa_$PROJECT1/" ~/.gitconfig-$PROJECT1

# Project 2
sed -i "s/Your Project2 Name/$NAME_PROJECT2/" ~/.gitconfig-$PROJECT2
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
    echo "✅ SSH key $keyname already exists. Skipping generation."
  fi
}

generate_ssh_key "id_rsa_personal" "$EMAIL_PERSONAL"
generate_ssh_key "id_rsa_$PROJECT1" "$EMAIL_PROJECT1"
generate_ssh_key "id_rsa_$PROJECT2" "$EMAIL_PROJECT2"

# Step 6: Add keys to agent
echo "🚀 Adding keys to SSH agent..."
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_personal
ssh-add ~/.ssh/id_rsa_$PROJECT1
ssh-add ~/.ssh/id_rsa_$PROJECT2

# Step 7: Done!
echo ""
echo "✅ Setup complete!"
echo "🧪 Test with:"
echo "   git config user.name"
echo "   git config user.email"
echo ""
echo "💡 Use: git config --list --show-origin to see which config Git is using."
