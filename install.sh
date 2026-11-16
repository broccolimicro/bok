#!/bin/sh

set -e
TEMP_DIR=""
cleanup() {
	[ -n "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

TAG=$(curl -Ls "https://api.github.com/repos/broccolimicro/bok/releases?per_page=1" | grep "\"name\": *\"v" | sed 's/.*: *"\(v[^"]*\)".*/\1/g')
OS=$(uname)
USER_NAME=$(id -un)

if [ "$OS" = "Linux" ]; then
	SHARE_DIR="/usr/local/share"
	TEMP_DIR="$(mktemp -d)"
	DEB_URL="https://github.com/broccolimicro/bok/releases/download/$TAG/bok-linux.deb"

	echo "Downloading installation files..."
	if curl -L --progress-bar --retry 3 --retry-delay 2 "$DEB_URL" -o "$TEMP_DIR/bok-linux.deb"; then
	  echo "Download successful."
	else
	  echo "Failed to download package. Please check the URL or your internet connection."
	  exit 1
	fi

	echo "Installing package..."
	echo "The following commands will be run with elevated privileges (sudo):"
	echo ""
	echo "  dpkg -i $TEMP_DIR/bok-linux.deb"
	echo "  groupadd cad # if needed"
	echo "  usermod -aG cad \"$USER_NAME\""
	echo "  mkdir -p \"$SHARE_DIR\""
	echo "  chown -R root:cad \"$SHARE_DIR/tech\""
	echo "  chmod -R ug+rw \"$SHARE_DIR/tech\""
	echo "  find \"$SHARE_DIR/tech\" -type d -exec chmod g+s {} \\;"
	echo ""
	while true; do
		read -r -p "Continue? [Y/n] " response </dev/tty
		case "$response" in
			[Yy]|'' ) break ;;	 # Default to yes if empty
			[Nn] ) echo "Installation cancelled."; exit 1 ;;
			* ) echo "Please enter Y or n." ;;
		esac
	done
	sudo USER_NAME="$USER_NAME" TEMP_DIR="$TEMP_DIR" sh <<EOF
set -e

dpkg -i "$TEMP_DIR/bok-linux.deb"

if ! getent group cad >/dev/null; then
	groupadd cad
fi

usermod -aG cad "$USER_NAME"
chown -R root:cad "$SHARE_DIR/tech"
chmod -R ug+rw "$SHARE_DIR/tech"
find "$SHARE_DIR/tech" -type d -exec chmod g+s {} \;
EOF
	
	# Post-install message
	echo "Installation complete!"
	echo "NOTE: '$USER_NAME' has been added to the 'cad' group."
	echo "You must log out and back in (or start a new login session)"
	echo "before the new group membership takes effect."
	echo ""
	echo "After login, you can now use the 'bok' command."
elif [ "$OS" = "Darwin" ]; then
	# Define target directories
	BIN_DIR="/usr/local/bin"
	SHARE_DIR="/usr/local/share"
	TEMP_DIR="$(mktemp -d)"
	TARBALL_URL="https://github.com/broccolimicro/bok/releases/download/$TAG/bok-macos.tar.gz"

	echo "Downloading installation files..."
	if curl -L --progress-bar --retry 3 --retry-delay 2 "$TARBALL_URL" -o "$TEMP_DIR/bok-macos.tar.gz"; then
	  echo "Download successful."
	else
	  echo "Failed to download tarball. Please check the URL or your internet connection."
	  exit 1
	fi

	echo "Extracting files..."
	if tar -xzf "$TEMP_DIR/bok-macos.tar.gz" -C "$TEMP_DIR"; then
	  echo "Extraction complete."
	else
	  echo "Failed to extract files. Exiting."
	  exit 1
	fi

	echo "Installing package..."
	echo "The following commands will be run with elevated privileges (sudo):"
	echo ""
	echo "  cp \"$TEMP_DIR/bok-macos/bin/bok\" \"$BIN_DIR\""
	echo "  cp -r \"$TEMP_DIR/bok-macos/share/tech\" \"$SHARE_DIR\""
	echo "  chmod +x \"$BIN_DIR/bok\""
	echo "  chown -R root:staff \"$SHARE_DIR/tech\""
	echo "  chmod -R ug+rw \"$SHARE_DIR/tech\""
	echo ""
	while true; do
		read -r -p "Continue? [Y/n] " response
		case "$response" in
			[Yy]|'' ) break ;;	 # Default to yes if empty
			[Nn] ) echo "Installation cancelled."; exit 1 ;;
			* ) echo "Please enter Y or n." ;;
		esac
	done
	sudo sh -c "
		cp \"$TEMP_DIR/bok-macos/bin/bok\" \"$BIN_DIR\" &&
		cp -r \"$TEMP_DIR/bok-macos/share/tech\" \"$SHARE_DIR\" &&
		chmod +x \"$BIN_DIR/bok\" &&
		chown -R root:staff \"$SHARE_DIR/tech\" &&
		chmod -R ug+rw \"$SHARE_DIR/tech\"
	"
	echo "Binary installed successfully."

	# Post-install message
	echo "Installation complete!"
	echo "You can now use the 'bok' command."
else
	# Define target directories
	BIN_DIR="C:\\Program Files (x86)"
	TEMP_DIR="$(mktemp -d)"
	TARBALL_URL="https://github.com/broccolimicro/bok/releases/download/$TAG/bok-windows.zip"

	echo "Downloading installation files..."
	if curl -L --progress-bar --retry 3 --retry-delay 2 "$TARBALL_URL" -o "$TEMP_DIR/bok-windows.zip"; then
	  echo "Download successful."
	else
	  echo "Failed to download tarball. Please check the URL or your internet connection."
	  exit 1
	fi

	echo "Extracting files..."
	if unzip "$TEMP_DIR/bok-windows.zip" -d "$TEMP_DIR"; then
	  echo "Extraction complete."
	else
	  echo "Failed to extract files. Exiting."
	  exit 1
	fi

	# Install binary
	echo "Installing Bok to $BIN_DIR..."
	if cp -r "$TEMP_DIR/Bok" "$BIN_DIR/"; then
	  chmod +x "$BIN_DIR/Bok/bin/bok"
	  chmod -R ug+rw "$BIN_DIR/Bok/share/tech"
	  echo "Bok installed successfully."
	else
	  echo "Failed to install Bok. Please check permissions and try again."
	  exit 1
	fi

	# Post-install message
	echo "Installation complete!"
	echo "You can now use the 'bok' command."
fi

