/*
   Copyright 2008-2020 Fabrizio Montesi <famontesi@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

from console import Console
from file import File
from protocols.http import DefaultOperationHttpRequest
from runtime import Runtime
from string_utils import StringUtils
from types.Binding import Binding

from .hooks import PreResponseHookIface, PostResponseHookIface

/// Configuration parameters
type Params {
	location?:string //< location on which the web server should be exposed. Default: socket://localhost:8080
	wwwDir?:string //< path to the directory containing the web files. Default: /var/lib/leonardo/www/
	defaultPage?:string	//< default page to be served when clients ask for a directory. Default: "index.html"
	/// configuration parameters for the HTTP input port
	httpConfig? {
		/// default = false
		debug?:bool { 
			showContent?:bool //< default = false
		}
	}
	PreResponseHook?:Binding //< Binding to a custom PreResponseHook
	PostResponseHook?:Binding //< Binding to a custom PostResponseHook
	/// Redirections to sub-services
	redirection* {
		name:string //< name of the service
		binding:Binding //< Binding to the target service
	}
}

interface HTTPInterface {
RequestResponse:
	default(DefaultOperationHttpRequest)(undefined)
}

service Leonardo( params:Params ) {
	execution: concurrent

	embed Console as Console
	embed StringUtils as StringUtils
	embed File as File
	embed Runtime as Runtime

	inputPort HTTPInput {
		protocol: http {
			keepAlive = true // Keep connections open
			debug = (!(params.httpConfig.debug instanceof void) && params.httpConfig.debug)
			debug.showContent = (!(params.httpConfig.debug.showContent instanceof void) && params.httpConfig.debug.showContent)
			format -> format
			contentType -> mime
			statusCode -> statusCode
			redirect -> redirect
			cacheControl.maxAge -> cacheMaxAge

			default = "default"
		}
		location: Location_Leonardo
		interfaces: HTTPInterface
	}

	outputPort PreResponseHook {
		interfaces: PreResponseHookIface
	}

	outputPort PostResponseHook {
		interfaces: PostResponseHookIface
	}

	define setCacheHeaders {
		shouldCache = false
		if ( s.result[0] == "image" ) {
			shouldCache = true
		} else {
			e = file.filename
			e.suffix = ".js"
			endsWith@StringUtils( e )( shouldCache )
			if ( !shouldCache ) {
				e.suffix = ".css"
				endsWith@StringUtils( e )( shouldCache )
				if ( !shouldCache ) {
						e.suffix = ".woff"
						endsWith@StringUtils( e )( shouldCache )
				}
			}
		}

		if ( shouldCache ) {
			cacheMaxAge = 60 * 60 * 2 // 2 hours
		}
	}

	define checkForMaliciousPath {
		for( maliciousSubstring in maliciousSubstrings ) {
			contains@StringUtils( s.result[0] { substring = maliciousSubstring } )( b )
			if ( b ) { throw( FileNotFound ) }
		}
	}

	define loadHooks {
		if ( is_defined( params.PreResponseHook ) ) {
			PreResponseHook << params.PreResponseHook
		} else {
			loadEmbeddedService@Runtime( {
				filepath = "../../internal/hooks/pre_response.ol"
				type = "Jolie"
			} )( PreResponseHook.location )
		}

		if ( is_defined( params.PostResponseHook ) ) {
			PostResponseHook << params.PostResponseHook
		} else {
			loadEmbeddedService@Runtime( {
				filepath = "../../internal/hooks/post_response.ol"
				type = "Jolie"
			} )( PostResponseHook.location )
		}
	}

	init {
		maliciousSubstrings[0] = ".."
		maliciousSubstrings[1] = ".svn"
		maliciousSubstrings[2] = ".git"
	}

	define setRedirections {
		for( redirection in params.redirection ) {
			with( request ) {
				.name = "#" + redirection.name;
				.location = redirection.binding.location;
				if ( is_defined( redirection.binding.protocol ) ) {
					.protocol << redirection.binding.protocol
				}
			}
			setOutputPort@Runtime( request )()
			undef( request )
			setRedirection@Runtime( {
				inputPortName = "HTTPInput"
				outputPortName = "#" + redirection.name
				resourceName = redirection.name
			} )()
		}
	}

	init {
		getenv@Runtime( "LEONARDO_WWW" )( config.wwwDir );
		if ( is_defined( args[0] ) ) {
			config.wwwDir = args[0]
		}

		if ( !is_defined( config.wwwDir ) || config.wwwDir instanceof void ) {
			config.wwwDir = RootContentDirectory
		}

		setRedirections
		undef( config.redirection )

		loadHooks
		undef( config.PreResponseHook )
		undef( config.PostResponseHook )

		toAbsolutePath@File( config.wwwDir )( config.wwwDir )
		getFileSeparator@File()( fs )
		config.wwwDir += fs

		getServiceParentPath@File()( dir )
		setMimeTypeFile@File( dir + fs + ".." + fs + ".." + fs + "internal" + fs + "mime.types" )()
		undef( dir )
		undef( fs )

		format = "html"
		println@Console( "Leonardo started\n\tLocation: " + global.inputPorts.HTTPInput.location + "\n\tWeb directory: " + config.wwwDir )()
	}

	main {
		[ default( request )( response ) {
			runPostResponseHook = false
			scope( computeResponse ) {
				install(
					FileNotFound =>
						println@Console( "File not found: " + file.filename )()
						statusCode = 404,
					MovedPermanently =>
						statusCode = 301
				)

				split@StringUtils( request.operation { regex = "\\?" } )( s )

				// Default page
				shouldAddIndex = false
				if ( s.result[0] == "" ) {
					shouldAddIndex = true
				} else {
					endsWith@StringUtils( s.result[0] { suffix = "/" } )( shouldAddIndex )
				}
				if ( shouldAddIndex ) {
					s.result[0] += DefaultPage
				}

				checkForMaliciousPath;

				requestPath = s.result[0];

				file.filename = config.wwwDir + requestPath;

				isDirectory@File( file.filename )( isDirectory );
				if ( isDirectory ) {
					redirect = requestPath + "/"
					throw( MovedPermanently )
				}

				getMimeType@File( file.filename )( mime )
				split@StringUtils( mime { .regex = "/" } )( s )
				if ( s.result[0] == "text" ) {
					file.format = "text"
					format = "html"
				} else {
					file.format = format = "binary"
				};

				setCacheHeaders

				readFile@File( file )( response )

				runPostResponseHook = true

				install( PreResponseFault =>
					response = computeResponse.PreResponseFault.response
					statusCode = computeResponse.PreResponseFault.statusCode
					runPostResponseHook = false
				)
				with( decoratedResponse ) {
					.config -> config;
					.request.path = requestPath;
					if ( file.format == "text" ) {
						.content -> response
					}
				}
				run@PreResponseHook( decoratedResponse )( newResponse )
				if ( !(newResponse instanceof void) ) {
					response -> newResponse
				}
			}
		} ] {
			if ( runPostResponseHook ) {
				run@PostResponseHook( decoratedResponse )()
			}
		}
	}
}
