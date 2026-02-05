# install lakos - see https://pub.dev/packages/lakos/install
# dart pub global activate lakos
# export PATH="$PATH":"$HOME/.pub-cache/bin"
echo "Generate Graph dependencies"

rm -f graph.dot > /dev/null
rm -f graph.svg > /dev/null

# lakos . --no-tree -o graph.dot --ignore=example/**
lakos . -o graph.dot --ignore=example/**
npx --yes github:jpdup/glad#25ebb08 graph.dot -o graph.svg --exclude "**/test/*"

# we dont need this file anymore, we just care about the svg output
rm -f graph.dot > /dev/null
