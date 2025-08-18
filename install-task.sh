#!/bin/bash

# Install Task (taskfile.dev) if not present
if ! command -v task &> /dev/null; then
    echo "📦 Installing Task..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install go-task/tap/go-task
        else
            echo "Please install Homebrew first: https://brew.sh"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo "❌ Unsupported OS. Please install Task manually: https://taskfile.dev/installation/"
        exit 1
    fi
    
    echo "✅ Task installed successfully"
else
    echo "✅ Task is already installed"
fi

echo ""
echo "🚀 Run the following commands to get started:"
echo "   task init    # Initialize project with setup wizard"
echo "   task deploy  # Deploy the complete cluster"
echo "   task doctor  # Check cluster health"
echo "   task --list  # Show all available commands"