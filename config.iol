constants {
	// The deployment location for reaching the Leonardo web server
	Location_Leonardo = "socket://localhost:8000/",

	// The root directory in which Leonardo will look for content to serve to clients
	RootContentDirectory = "www/",

	// The default page to serve in case clients do not specify one
	DefaultPage = "index.html",

	// Print debug messages for all exchanged HTTP messages
	DebugHttp = false,

	// Add the content of every HTTP message to their debug messages
	DebugHttpContent = false
}
