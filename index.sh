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

# Checking for changes and finding applications to close
if diff $INITIAL_APPS $EDITED_APPS >/dev/null; then
	echo "No changes detected."
else
	echo "Changes detected. Finding applications to close..."
	MISSING_APPS=()
	while IFS= read -r line; do
		if ! grep -Fxq "$line" $EDITED_APPS; then
			MISSING_APPS+=("$line")
		fi
	done <$INITIAL_APPS

	if [ ${#MISSING_APPS[@]} -eq 0 ]; then
		echo "No applications to close."
	else
		echo "The following applications will be closed:"
		for APP in "${MISSING_APPS[@]}"; do
			printf "\t- %s\n" "$APP"
		done

		# Ask for confirmation before closing applications
		read -p "Are you sure you want to close these applications? (y/n) " confirm
		if [[ $confirm =~ ^[Yy]$ ]]; then
			for APP in "${MISSING_APPS[@]}"; do
				echo "Closing $APP..."
				# Extract only the app name for the quit command
				APP_NAME=$(echo "$APP" | sed 's/\.app$//i')
				osascript -e "tell application \"$APP_NAME\" to quit"
			done
			echo "Applications closed."
		else
			echo "Operation cancelled."
		fi
	fi
fi

# Clean up
rm $INITIAL_APPS $EDITED_APPS
echo "Process complete."
