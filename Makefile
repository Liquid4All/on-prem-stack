# Makefile
.PHONY: build install

build:
	go build -o bin/liquidai-cli cmd/liquidai-cli/main.go

install:
	go install ./cmd/liquidai-cli
