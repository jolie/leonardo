include "../types/PreResponseHookIface.iol"

execution { concurrent }

inputPort Input {
Location: "local"
Interfaces: PreResponseHookIface
}

main
{
	run(mesg)(mesg.content)
}
