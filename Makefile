.PHONY : test

PATH := ./node_modules/.bin/:$(PATH)

%.js : *.coffee
	@coffee -c $<

test: index.js
	@mocha --compilers coffee:coffee-script
