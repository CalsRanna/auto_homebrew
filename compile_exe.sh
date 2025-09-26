#!/bin/bash

set -e

mkdir -p build
dart compile exe bin/tapster.dart -o build/tapster
