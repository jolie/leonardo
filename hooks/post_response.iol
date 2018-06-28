include "hooks_types.iol"

service PostResponseHook {
Interfaces: PostResponseHookIface
main {
	run(mesg)(mesg) {
		nullProcess
	}
}
}
