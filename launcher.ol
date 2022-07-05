#!/usr/bin/env jolie

/*
   Copyright 2020-2021 Fabrizio Montesi <famontesi@gmail.com>

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

from runtime import Runtime
from file import File

service Launcher {
	embed Runtime as runtime
	embed File as file

	main {
		dir =
			if( args[0] instanceof string ) args[0]
			else getenv@runtime( "LEONARDO_WWW" )

		if( dir instanceof string ) {
			config.wwwDir = dir
		}

		config.location = "socket://localhost:8080"
		config.defaultPage = "index.html"

		getRealServiceDirectory@file()( home )
		getFileSeparator@file()( sep )

		loadEmbeddedService@runtime( {
			filepath = home + sep + "main.ol"
			service = "Leonardo"
			params -> config
		} )()

		linkIn( Shutdown )
	}
}