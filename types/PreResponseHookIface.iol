include "hooks_types.iol"

type PreResponseFaultType:void {
	.statusCode:int
	.response:string
}

type MaybeString: void | string

interface PreResponseHookIface {
RequestResponse: run(DecoratedResponse)(MaybeString) throws PreResponseFault(PreResponseFaultType)
}
