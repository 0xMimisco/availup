#!/usr/bin/env bash
echo "🆙 Starting Availup..."
while [ $# -gt 0 ]; do
    if [[ $1 = "--"* ]]; then
        v="${1/--/}"
        declare "$v"="$2"
        shift
    fi
    shift
done
# check if bash is current terminal shell, else check for zsh
if [ -z "$BASH_VERSION" ]; then
    if [ -z "$ZSH_VERSION" ]; then
        echo "🚫 Unable to locate a shell. Availup might not work as intended!"
    else 
        CURRENT_TERM="zsh"
    fi
else
    CURRENT_TERM="bash"
fi
if [ "$CURRENT_TERM" = "bash" -a -f "$HOME/.bashrc" ]; then
    PROFILE="$HOME/.bashrc"
elif [ "$CURRENT_TERM" = "bash" -a -f "$HOME/.bash_profile" ]; then
    PROFILE="$HOME/.bash_profile"
elif [ "$CURRENT_TERM" = "bash" -a -f "$HOME/.zshrc" ]; then
    PROFILE="$HOME/.zshrc"
elif [ "$CURRENT_TERM" = "bash" -a -f "$HOME/.zsh_profile" ]; then
    PROFILE="$HOME/.zsh_profile"
elif [ "$CURRENT_TERM" = "zsh" -a -f "$HOME/.zshrc" ]; then
    PROFILE="$HOME/.zshrc"
elif [ "$CURRENT_TERM" = "zsh" -a -f "$HOME/.zsh_profile" ]; then
    PROFILE="$HOME/.zsh_profile"
elif [ "$CURRENT_TERM" = "bash" ]; then
    PROFILE="$HOME/.bashrc"
    touch $HOME/.bashrc
elif [ "$CURRENT_TERM" = "zsh" ]; then
    PROFILE="$HOME/.zshrc"
    touch $HOME/.zshrc
else
    echo "🫣 Unable to locate a compatible shell or rc file, using POSIX default, availup might not work as intended!"
    PROFILE="/etc/profile"
fi
if [ -z "$network" ]; then
    echo "🛜  No network selected. Defaulting to goldberg."
    NETWORK="goldberg"
else 
    NETWORK="$network"
fi
if [ "$NETWORK" = "goldberg" ]; then
    echo "📌 Goldberg network selected."
    VERSION="v1.7.9"
elif [ "$NETWORK" = "local" ]; then
    echo "📌 Local network selected."
    VERSION="v1.7.9"
else
    echo "🚫 Invalid network selected. Please select one of the following: goldberg, kate, local."
    exit 1
fi
if [ -z "$app_id" ]; then
    echo "📲 No app ID specified. Defaulting to 0."
    APPID="0"
else 
    APPID="$app_id"
fi
if [ -z "$identity" ]; then
    IDENTITY=$HOME/.avail/identity/identity.toml
    if [ -f "$HOME/.avail/identity/identity.toml" ]; then
        echo "🔑 Identity found at $IDENTITY."
    else 
        echo "🤷 No identity set. This will be automatically generated at startup."
    fi
else 
    IDENTITY="$identity"
fi
if [ ! -d "$HOME/.avail" ]; then
    mkdir $HOME/.avail
fi
if [ ! -d "$HOME/.avail/bin" ]; then
    mkdir $HOME/.avail/bin
fi
if [ ! -d "$HOME/.avail/identity" ]; then
    mkdir $HOME/.avail/identity
fi
# check if avail-light version matches!
UPGRADE=0
if [ ! -z "$upgrade" ]; then
    echo "🔄 Checking for updates..."
    if command -v avail-light >/dev/null 2>&1; then
        CURRENT_VERSION="v$(avail-light --version | cut -d " " -f 2)"
        if [ "$CURRENT_VERSION" = "v1.7.8" ] && [ "$VERSION" = "v1.7.9" ]; then
            UPGRADE=0
            echo "✨ Avail binary is up to date. Skipping upgrade."
        elif [ "$CURRENT_VERSION" != "$VERSION" ]; then
            UPGRADE=1
            echo "✨ Avail binary is up to date. Skipping upgrade."
        else
            if [ "$upgrade" = "y" ] || [ "$upgrade" = "yes" ]; then
                UPGRADE=1
            fi
        fi
    fi
fi

onexit() {
    echo "🔄 Avail stopped. Future instances of the light client can be started by invoking the avail-light binary or rerunning this script$EXTRAPROMPT"
    if [[ ":$PATH:" != *":$HOME/.avail/bin:"* ]]; then
        if ! grep -q "export PATH=\"\$PATH:$HOME/.avail/bin\"" "$PROFILE"; then
            echo -e "export PATH=\"\$PATH:$HOME/.avail/bin\"\n" >> $PROFILE
        fi
        echo -e "📌 Avail has been added to your profile. Run the following command to load it in the current terminal session:\n. $PROFILE\n"
    fi
    exit 0
}
# check if avail-light binary is available and check if upgrade variable is set to 0
if command -v avail-light >/dev/null 2>&1 && [ "$UPGRADE" = 0 ]; then
    echo "✅ Avail is already installed. Starting Avail..."
    trap onexit EXIT
    if [ -z "$config" ] && [ ! -z "$identity" ]; then
        $HOME/.avail/bin/avail-light --network $NETWORK --app-id $APPID --identity $IDENTITY
    elif [ -z "$config" ]; then
        $HOME/.avail/bin/avail-light --network $NETWORK --app-id $APPID
    elif [ ! -z "$config" ] && [ ! -z "$identity" ]; then
        $HOME/.avail/bin/avail-light --config $CONFIG --app-id $APPID --identity $IDENTITY
    else
        $HOME/.avail/bin/avail-light --config $CONFIG --app-id $APPID
    fi
    exit 0
fi
if [ "$UPGRADE" = 1 ]; then
    echo "🔄 Upgrading Avail..."
    if [ -f "$HOME/.avail/bin/avail-light" ]; then
        rm $HOME/.avail/bin/avail-light
    else
        echo "🤔 Avail was not installed with availup. Attemping to uninstall with cargo..."
        cargo uninstall avail-light || echo "👀 Avail was not installed with cargo, upgrade might not be required!"
        if command -v avail-light >/dev/null 2>&1; then
            echo "🚫 Avail was not uninstalled. Please uninstall manually and try again."
            exit 1
        fi
    fi
fi
if [ "$(uname -m)" = "arm64" -a "$(uname -s)" = "Darwin" ]; then
    ARCH_STRING="apple-arm64"
elif [ "$(uname -m)" = "x86_64" -a "$(uname -s)" = "Darwin" ]; then
    ARCH_STRING="apple-x86_64"
elif [ "$(uname -m)" = "aarch64" -o "$(uname -m)" = "arm64" ]; then
    ARCH_STRING="linux-aarch64"
elif [ "$(uname -m)" = "x86_64" ]; then
    ARCH_STRING="linux-amd64"
fi
if [ -z "$ARCH_STRING" ]; then
    echo "📥 No binary available for this architecture, building from source instead. This can take a while..."
    # check if cargo is not available, else attempt to install through rustup
    if command -v cargo >/dev/null 2>&1; then
        echo "📦 Cargo is available. Building from source..."
    else
        echo "👀 Cargo is not available. Attempting to install with Rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        EXTRAPROMPT="\nℹ️ Cargo env needs to be loaded by running source \$HOME/.cargo/env"
        echo "📦 Cargo is now available. Reattempting to build from source..."
    fi
    # check if avail-light folder exists in home directory, if yes, pull latest changes, else clone the repo
    echo "📂 Cloning avail-light repository and building..."
    git clone -q -c advice.detachedHead=false --depth=1 --single-branch --branch $VERSION https://github.com/availproject/avail-light.git $HOME/avail-light
    cd $HOME/avail-light
    cargo install --locked --path . --bin avail-light
    rm -rf $HOME/avail-light
else
    if command -v curl >/dev/null 2>&1; then
        curl -sLO https://github.com/availproject/avail-light/releases/download/$VERSION/avail-light-$ARCH_STRING.tar.gz
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://github.com/availproject/avail-light/releases/download/$VERSION/avail-light-$ARCH_STRING.tar.gz
    else
        echo "🚫 Neither curl nor wget are available. Please install one of these and try again."
        exit 1
    fi
    # use tar to extract the downloaded file and move it to /usr/local/bin
    tar -xzf avail-light-$ARCH_STRING.tar.gz
    chmod +x avail-light-$ARCH_STRING
    mv avail-light-$ARCH_STRING $HOME/.avail/bin/avail-light
    rm avail-light-$ARCH_STRING.tar.gz
fi
echo "✅ Availup exited successfully."
echo "🧱 Starting Avail."
trap onexit EXIT
if [ -z "$config" ] && [ ! -z "$identity" ]; then
    $HOME/.avail/bin/avail-light --network $NETWORK --app-id $APPID --identity $IDENTITY
elif [ -z "$config" ]; then
    $HOME/.avail/bin/avail-light --network $NETWORK --app-id $APPID
elif [ ! -z "$config" ] && [ ! -z "$identity" ]; then
    $HOME/.avail/bin/avail-light --config $CONFIG --app-id $APPID --identity $IDENTITY
else
    $HOME/.avail/bin/avail-light --config $CONFIG --app-id $APPID
fi
