#!/bin/sh

set -euo pipefail

if mysqladmin ping -h localhost; then
	exit 0
fi

exit 1
