if [ $# -lt 1 ]; then
    echo "Input arguments missing."
    echo "arg1: hyp root directory."
    echo "Fex. ./virt-docker-run.sh <path>/pkvm-aarch64"
    exit 1
fi

export HYP_BUILD_ROOT=$1

docker run -it --rm \
		-v ${HYP_BUILD_ROOT}:/hyp \
		-v/dev:/dev \
		-v/lib/modules:/lib/modules:ro \
		--cap-add=SYS_ADMIN --privileged=true \
		pkvm_virt
