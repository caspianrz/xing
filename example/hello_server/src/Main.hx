package;

import xing.Xing;

class Main {
    public static function main() {
        var x = new Xing();
		x.registerRoute("/", function(req, res) {
			res.setBody("Hello World");
			res.send();
		});

		x.registerRoute("/hello", (req: xing.request.Request, res) -> {
			var context : xing.template.Context = new xing.template.Context();
			context.addString("name", "world");
			try {
				var template = xing.template.Template.fromString("Hello {{
					if(12 == 13) {
						name = 'xing';
						$ name $
					} else {
						$ 'cruel ' + name $
					}
				}}.", context);
				res.setBody(template);
				res.send();
			} catch(e:haxe.Exception) {
				res.setStatus(500);
				var j = {
					message: e.toString(),
				};
				res.setBody(haxe.Json.stringify(j));
				res.send();
				return;
			}
		});

		x.listen("0.0.0.0", [8000], function() {
			Sys.println('Listening on http://0.0.0.0:8000');
		});
    }
}