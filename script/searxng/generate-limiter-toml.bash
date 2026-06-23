#!/usr/bin/env bash

## Define the path to the limiter template file and the final limiter configuration file.
## The template file is read-only and contains placeholders for environment variables,
## while the final configuration file is written to by this script and read by SearXNG.
LIMITER_TOML_TEMPORARY_FILE="${LIMITER_TOML_TEMPORARY_FILE:-'/tmp/searxng/limiter.toml.tmp'}";

## We'll need to read the limiter template file line by line so we can run string interpolation on it,
## but we also need to preserve the formatting of the file, so we'll use a here document to do that.
while IFS='' read -r line || [ -n "${line}" ]; do

    ## We'll need to echo the line so we can run string interpolation on it, but we also
    ## need to preserve the formatting of the line, so we'll use a here document to do that.
    bash -c "cat <<EOF
${line}
EOF";

## We're done with the lines, read the template file and write the output to a temporary file.
done < "${LIMITER_TOML_TEMPLATE}" > "${LIMITER_TOML_TEMPORARY_FILE}";

## Now we'll move the temporary file to the final location.
cat "${LIMITER_TOML_TEMPORARY_FILE}" > "${LIMITER_TOML}";

## Ensure SearXNG can read the limiter configuration file.
chmod 0644 "${LIMITER_TOML}";

## Clean up the temporary file.
rm -f "${LIMITER_TOML_TEMPORARY_FILE}";
