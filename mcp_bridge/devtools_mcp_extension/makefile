all: build_extension

build_extension:
	flutter build web --release
	flutter pub run devtools_extensions build_and_copy --source=build/web --dest=extension/devtools/build

validate_extension:
	flutter pub run devtools_extensions validate --package=.

clean:
	rm -rf extension/devtools/build
	cd web_app && flutter clean

run: 
	flutter run -d chrome --dart-define=use_simulated_environment=true

publish:
	flutter pub publish

dry-run:
	flutter pub publish --dry-run

gen:
	flutter pub run build_runner build 
