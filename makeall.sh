#!/usr/bin/env bash

for d in build*/; do
  (
    echo -e "\033[1mNow building '$d'...\033[0m"
    cd "$d" && make -j8 && echo -e "\033[1;32mSucceeded building '$d'!\033[0m" || echo -e "\033[1;31mFailed building '$d'!\033[0m"
  )
done
