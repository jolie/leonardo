include "../types/PostResponseHookIface.iol"

execution { concurrent }

inputPort Input {
Location: "local"
Interfaces: PostResponseHookIface
}

main {
	run(mesg)()
}
