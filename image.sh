#!/usr/bin/env bash
magick convert -auto-orient -resize "1920x1920>" "$1" "$2"
