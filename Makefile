.PHONY : test

test:
	@./node_modules/.bin/mocha --compilers coffee:coffee-script
