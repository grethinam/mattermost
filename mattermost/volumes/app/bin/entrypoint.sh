#!/bin/sh

# Function to generate a random salt
generate_salt() {
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 48 | head -n 1
}

#Install required packages as root
echo "Current user is......$(whoami)"
echo "Current directory....$(pwd)"
apk add --no-cache sudo ca-certificates curl jq libc6-compat libffi-dev linux-headers mailcap netcat-openbsd xmlsec-dev

#Deciding package download based on edition
if [ "$edition" = "team" ]
then 
   curl https://releases.mattermost.com/$MM_VERSION/mattermost-team-$MM_VERSION-linux-amd64.tar.gz | tar -xvz 
else
   curl https://releases.mattermost.com/$MM_VERSION/mattermost-$MM_VERSION-linux-amd64.tar.gz | tar -xvz
fi

if [ -f "${MM_CONFIG}" ]; then
  echo "Back up config file ${MM_CONFIG}"
  mv "${MM_CONFIG}" /config.json.save
else
  echo "No config file ${MM_CONFIG}"
fi

#Creating application User
addgroup -g ${PGID} mattermost && adduser -D -u ${PUID} -G mattermost -h /mattermost -D mattermost && chown -R mattermost:mattermost /mattermost /config.json.save


# Read environment variables or set default values
DB_HOST=${DB_HOST:-mysql}
DB_PORT_NUMBER=${DB_PORT_NUMBER:-3306}
MM_USERNAME=${MM_USERNAME:-mmuser}
MM_PASSWORD=${MM_PASSWORD:-mmuser_password}
MM_DBNAME=${MM_DBNAME:-mattermost}
MM_CONFIG=${MM_CONFIG:-/mattermost/config/config.json}
ARGVAR=mattermost
ENCODED_PASSWORD=$(printf %s $MM_PASSWORD | jq -s -R -r @uri)
MM_SQLSETTINGS_DATASOURCE="$MM_USERNAME:$ENCODED_PASSWORD@tcp($DB_HOST:$DB_PORT_NUMBER)/$MM_DBNAME?charset=utf8mb4,utf8"

if [ "${1:0:1}" = '-' ]; then
    set -- mattermost "$@"
fi

if [ "$ARGVAR" = 'mattermost' ]; then
  # Check CLI args for a -config option
  for ARG in $@;
  do
      case "$ARG" in
          -config=*)
              MM_CONFIG=${ARG#*=};;
      esac
  done

  if [ ! -f $MM_CONFIG ]
  then
    # If there is no configuration file, create it with some default values
    echo "No configuration file" $MM_CONFIG
    echo "Creating a new one"
    # Copy default configuration file
    cp /config.json.save $MM_CONFIG
    # Substitue some parameters with jq
    jq '.ServiceSettings.ListenAddress = ":8000"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.LogSettings.EnableConsole = false' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.LogSettings.ConsoleLevel = "INFO"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.FileSettings.Directory = "/mattermost/data/"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.FileSettings.EnablePublicLink = true' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.FileSettings.PublicLinkSalt = "'$(generate_salt)'"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.EmailSettings.SendEmailNotifications = false' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.EmailSettings.FeedbackEmail = ""' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.EmailSettings.SMTPServer = ""' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.EmailSettings.SMTPPort = ""' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.EmailSettings.InviteSalt = "'$(generate_salt)'"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.EmailSettings.PasswordResetSalt = "'$(generate_salt)'"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.RateLimitSettings.Enable = true' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.SqlSettings.DriverName = "mysql"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.SqlSettings.AtRestEncryptKey = "'$(generate_salt)'"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
    jq '.SqlSettings.DataSource = "'$(echo -n $MM_SQLSETTINGS_DATASOURCE)'"' $MM_CONFIG > $MM_CONFIG.tmp && mv $MM_CONFIG.tmp $MM_CONFIG
  else
    echo "Using existing config file" $MM_CONFIG
  fi

  # Wait for database to be reachable
  echo "Wait until database $DB_HOST:$DB_PORT_NUMBER is ready..."
  until nc -z $DB_HOST $DB_PORT_NUMBER
  do
    sleep 1
  done

  # Wait another second for the database to be properly started.
  # Necessary to avoid "panic: Failed to open sql connection pq: the database system is starting up"
  sleep 1

  echo "Starting mattermost"
fi

#Change ownership of configuration file
chown -R mattermost:mattermost /mattermost/config/config.json

echo "Argument : $@"
sudo -u mattermost  -- sh -c "echo "Current user is......$(whoami)";echo "Current directory....$(pwd)";cd /mattermost/i18n;pwd;"$@""
