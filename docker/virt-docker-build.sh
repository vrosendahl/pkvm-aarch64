if ! [[ -e gitconfig ]]; then
    echo "Copying ~/.gitconfig here.."
    if ! [[ -e ~/.gitconfig ]]; then
        echo "There is no ~/.gitconfig. Provide it manually, please"
        exit 1
    else
        cp ~/.gitconfig $(dirname $0)/gitconfig
    fi
fi

docker build --build-arg userid=$(id -u) --build-arg groupid=$(id -g) --build-arg username=$(id -un) -t pkvm_virt .
