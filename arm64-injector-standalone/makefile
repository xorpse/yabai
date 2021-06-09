all: sa_arm64e.h
	clang -o inject inject.c -arch arm64e -std=c99 -Wall -DNDEBUG -O2 -fvisibility=hidden -mmacosx-version-min=10.13

sa_arm64e.h:
	./extract.sh

clean:
	rm -f inject inject.o
	rm -f sa_arm64e sa_arm64e.o sa_arm64e.h
