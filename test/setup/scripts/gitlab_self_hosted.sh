#!/bin/bash
# GitLab Installation
apt-get update
apt-get install -y curl openssh-server ca-certificates tzdata perl jq
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | bash
apt-get install gitlab-ee=17.11.2-ee.0

# Retrieve values from Metadata Server
EXTERNAL_IP=$(curl http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
PROJECT_ID=$(curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
URL="https://$EXTERNAL_IP.sslip.io"

openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 3650 -nodes \
-subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=gitlab.example.com" \
-addext "subjectAltName=DNS:gitlab.example.com, IP:$EXTERNAL_IP, DNS:$EXTERNAL_IP.sslip.io"

mv key.pem gitlab.key
mv cert.pem gitlab.crt

mkdir -p /etc/gitlab/ssl
cp gitlab.* /etc/gitlab/ssl

cat > /etc/gitlab/gitlab.rb <<EOF
external_url "https://gitlab.example.com"
nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.key"
letsencrypt['enable'] = false
EOF

gitlab-ctl reconfigure

MAX_TRIES=50
# Wait for the server to handle authentication requests
for (( i=1; i<=MAX_TRIES; i++)); do
  RESPONSE_BODY=$(curl --cacert /etc/gitlab/ssl/gitlab.crt "$URL")

  if echo "$RESPONSE_BODY" | grep -q "You are .*redirected"; then
      personal_token=$(tr -dc "[:alnum:]" < /dev/random | head -c 20)
      gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: ['api', 'read_api', 'read_user'], name: 'Automation token', expires_at: 365.days.from_now); token.set_token('$personal_token'); token.save!"

      if gcloud secrets describe gitlab-pat-from-vm --project="$PROJECT_ID"; then
        echo -n "$personal_token" | gcloud secrets versions add gitlab-pat-from-vm --project="$PROJECT_ID" --data-file=-
      else
        echo -n "$personal_token" | gcloud secrets create gitlab-pat-from-vm --project="$PROJECT_ID" --data-file=-
      fi
      break
  else
      sleep 10
  fi

  if [ "$i" -eq $MAX_TRIES ]; then
        echo "ERROR: Reached limit of $MAX_TRIES tries"
        exit 1
  fi
done
