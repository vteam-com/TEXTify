@REM rem install lakos - see https://pub.dev/packages/lakos/install
@REM rem dart pub global activate lakos
@REM rem export PATH="$PATH":"$HOME/.pub-cache/bin"

echo "Generate Graph dependencies"

del graph.dot
del graph.svg
@REM del example\.dart_tool /S /Q

@REM rem with folders
call lakos . --no-tree -o graph.dot -i example/**

@REM rem remove the folders
@REM rem lakos -o graph.dot --no-tree --metrics --ignore=test/** .

call dot -Tsvg graph.dot -Grankdir=TB -Gcolor=lightgray -Ecolor="#aabbaa88" -o graph.svg
@REM rem fdp -Tsvg graph.dot -Gcolor=lightgray -Ecolor="#aabbaa99" -o graph.svg
