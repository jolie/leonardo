type HookBinding:void {
	.location:any
	.protocol?:string { ? }
}

type LeonardoConfiguration:void {
	.wwwDir?:string
	.PreResponseHook?:HookBinding
	.PostResponseHook?:HookBinding
}

interface LeonardoAdminIface {
RequestResponse: config(LeonardoConfiguration)(void)
}
