#!/bin/bash

# Temporary files for application names
INITIAL_APPS=$(mktemp)
EDITED_APPS=$(mktemp)

# Fetch initial list of applications including .app suffix and open in Neovim for editing
osascript -e '
tell application "System Events"
    set appList to ""
    set allApps to every application process where background only is false
    repeat with i from 1 to count of allApps
        set anApp to item i of allApps
        try
            if exists file of anApp then
                set appName to name of file of anApp
            else
                set appName to name of anApp
            end if
            set appList to appList & appName
            if i is not (count of allApps) then
                set appList to appList & "\n"
            end if
        end try
    end repeat
    return appList
end tell' >$INITIAL_APPS

cp $INITIAL_APPS $EDITED_APPS
nvim $EDITED_APPS

# Checking for changes and finding applications to close and to open
if diff $INITIAL_APPS $EDITED_APPS >/dev/null; then
	echo "No changes detected."
else
	echo "Changes detected. Analyzing..."
	MISSING_APPS=()
	NEW_APPS=()
	while IFS= read -r line; do
		if ! grep -Fxq "$line" $EDITED_APPS; then
			MISSING_APPS+=("$line")
		fi
	done <$INITIAL_APPS

	while IFS= read -r line; do
		if ! grep -Fxq "$line" $INITIAL_APPS; then
			NEW_APPS+=("$line")
		fi
	done <$EDITED_APPS

	if [ ${#MISSING_APPS[@]} -eq 0 ] && [ ${#NEW_APPS[@]} -eq 0 ]; then
		echo "No applications to close or open."
	else
		if [ ${#MISSING_APPS[@]} -ne 0 ]; then
			echo "The following applications will be closed:"
			for APP in "${MISSING_APPS[@]}"; do
				printf "\t- %s\n" "$APP"
			done
		fi

		if [ ${#NEW_APPS[@]} -ne 0 ]; then
			echo "The following applications will be opened:"
			for APP in "${NEW_APPS[@]}"; do
				printf "\t- %s\n" "$APP"
			done
		fi

		# Ask for confirmation before closing/opening applications
		read -p "Proceed with closing/opening applications? (y/n) " confirm
		if [[ $confirm =~ ^[Yy]$ ]]; then
			for APP in "${MISSING_APPS[@]}"; do
				echo "Closing $APP..."
				APP_NAME=$(echo "$APP" | sed 's/\.app$//i')
				osascript -e "tell application \"$APP_NAME\" to quit"
			done
			for APP in "${NEW_APPS[@]}"; do
				echo "Opening $APP..."
				APP_NAME=$(echo "$APP" | sed 's/\.app$//i')
				osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null || echo "Warning: Failed to open $APP_NAME. It might not exist."
			done
			echo "Applications updated."
		else
			echo "Operation cancelled."
		fi
	fi
fi

# Clean up
rm $INITIAL_APPS $EDITED_APPS
echo "Process complete."
