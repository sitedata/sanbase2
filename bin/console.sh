#!/bin/bash

docker-compose exec sanbase iex \
  --sname console \
  --cookie sanbase \
  --remsh "sanbase@sanbase_host" \
  --erl "-kernel shell_history enabled"
