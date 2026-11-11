#!/usr/bin/env bash
magick "$1" -auto-orient -resize "3840x3840>" -define jxl:distance=2.2 "$2"
