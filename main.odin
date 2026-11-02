package main

import "core:strconv"
import "core:unicode"
import "core:fmt"
import "core:os"
import "core:bufio"
import "core:strings"

TokenKind :: enum {
	PUSH,
	POP,
	ADD,
	SUB,
	PRINT_CHAR,
	PRINT_NUM,
	INPUT_STRING,
	INPUT_NUM,
	INVERT,
	LOOP_START,
	LOOP_END,
	COMPARE,
	DUPLICATE,
	END,
	CLEAR,
	NUMBER
}

Token :: struct {
	kind: TokenKind,
	value: int
}

tokenize :: proc(line: string) -> [dynamic]Token {
	tokenized: [dynamic]Token
	i: int = 0
	l: int = len(line)

	for i < l {
		ch: rune = rune(line[i])

		kind: TokenKind
		is_symbol := true

		switch ch {
		case '>': kind = .PUSH
		case '<': kind = .POP
		case '+': kind = .ADD
		case '-': kind = .SUB
		case '@': kind = .PRINT_CHAR
		case '%': kind = .PRINT_NUM
		case '#': kind = .INPUT_STRING
		case '^': kind = .INPUT_NUM
		case '$': kind = .INVERT
		case ':': kind = .LOOP_START
		case ';': kind = .LOOP_END
		case '?': kind = .COMPARE
		case '=': kind = .DUPLICATE
		case '!': kind = .END
		case '&': kind = .CLEAR
		case: is_symbol = false
		}

		if is_symbol {
			append(&tokenized, Token{kind, 0})
			i += 1
		} else if unicode.is_digit(ch) {
			j: int = i

			for j < l && unicode.is_digit(rune(line[j])) {
				j += 1
			}

			value, ok := strconv.parse_int(line[i:j])
			append(&tokenized, Token{.NUMBER, value})
			i = j
		} else if unicode.is_alpha(ch) {
			j: int = i

			for j < l {
				j += 1
			}

			i = j
		} else if unicode.is_white_space(ch) {
			i += 1
		} else {
			fmt.println("Invalid expression:", ch)
			i += 1
		}

	}

	return tokenized
}

evaluate_bolaga :: proc(stack: ^[dynamic]int, tokenList: [dynamic]Token) {
	i: int

	for i < len(tokenList) {
		token: Token = tokenList[i]

		switch token.kind {
			case .PUSH:
				append(stack, tokenList[i+1].value)
				i += 2
			case .POP:
				pop(stack)
				i += 1
			case .ADD:
				a := stack[len(stack)-1]
				b := stack[len(stack)-2]
				pop(stack)
				pop(stack)
				append(stack, a+b)
				i += 1
			case .SUB:
				a := pop(stack)
				b := pop(stack)
				append(stack, a-b)
				i += 1
			case .PRINT_CHAR:
				fmt.print(rune(pop(stack)))
				i += 1
			case .PRINT_NUM:
				fmt.print(pop(stack))
				i += 1
			case .INPUT_STRING:
				reader: bufio.Reader
				bufio.reader_init(&reader, os.to_stream(os.stdin))
				line, err := bufio.reader_read_string(&reader, '\n')
				line = strings.trim_space(line)

				if err != nil {
					fmt.println(err)
					return
				}

				line = strings.reverse(line)

				for c in line {
					append(stack, cast(int) c)
				}

				i += 1
			case .INPUT_NUM:
				reader: bufio.Reader
				bufio.reader_init(&reader, os.to_stream(os.stdin))
				line, err := bufio.reader_read_string(&reader, '\n')
				line = strings.trim_space(line)

				if err != nil {
					fmt.println(err)
					return
				}

				result, ok := strconv.parse_int(line)

				append(stack, result)

				i += 1
			case .INVERT: {
				for j in 0 ..< len(stack)/2 {
					stack[j], stack[len(stack) - j - 1] = stack[len(stack) - j - 1], stack[j]
				}
				i += 1
			}
			case .LOOP_START: {
				j: int = i + 1
				depth: int = 1
				loopInstructions: [dynamic]Token

				for j < len(tokenList) && depth > 0 {
					t := tokenList[j]

					if t.kind == .LOOP_START {
						depth += 1
					} else if t.kind == .LOOP_END {
						depth -= 1
					}

					if depth > 0 {
						append(&loopInstructions, t)
					}

					j += 1
				}

				if depth != 0 {
					fmt.println("Undetermined loop")
					return
				}

				for len(stack) > 0 && stack[len(stack) - 1] != 0 {
					evaluate_bolaga(stack, loopInstructions)
				}

				delete(loopInstructions)
				i = j
			}
			case .COMPARE:
				a: int = stack[len(stack) - 1]
				b: int = stack[len(stack) - 2]
				if a == b {
					i += 1
				} else {
					if i+1 < len(tokenList) && tokenList[i+1].kind == .LOOP_START {
						j := i+2
						depth := 1
						for j < len(tokenList) && depth > 0 {
							t := tokenList[j]
							if t.kind == .LOOP_START {
								depth += 1
							} else if t.kind == .LOOP_END {
								depth -= 1
							}

							j += 1
						}

						i = j
					} else {
						i += 2
					}
				}
			case .DUPLICATE: {
				append(stack, stack[len(stack)-1])
				i += 1
			}
			case .END:
				fmt.println(stack^)
				os.exit(0)
			case .CLEAR:
				clear(stack)
				i += 1
			case .LOOP_END:
			case .NUMBER:
				fmt.println("Invalid token in parse stream")
				return
		}

	}
}

main :: proc() {
	stack: [dynamic]int

	f, f_err := os.open(os.args[1])
	if f_err != nil {
		fmt.println(f_err)
		return
	}

	r: bufio.Reader
	bufio.reader_init(&r, os.to_stream(f))

	tokenList: [dynamic]Token

	for {
		line, err := bufio.reader_read_string(&r, '\n')
		if err != nil {
			break
		}
		defer delete(line)

		res := tokenize(line)
		append(&tokenList, ..res[:])
	}

	evaluate_bolaga(&stack, tokenList)

	delete(stack)
	delete(tokenList)
	bufio.reader_destroy(&r)
}
