# Build and publish images
# Copyright a2s-institute, Hochschule Bonn-Rhein-Sieg

CONTAINER_REGISTRY=""
PUBLISH="all"
IMAGE="base-gpu-notebook"
CUDA_VERSION="cuda11.8.0-ubuntu20.04"

show_help() {
  echo "Usage: bash build-and-deploy.sh"
  echo " "
  echo "options:"
  echo "-h, --help                    show brief help"
  echo "-r, --registry                container registry e.g. ghcr.io for GitHub container registry, default: docker hub"
  echo "-p, --publish                 option whether to publish <all> or <latest> (default: all), all means publish all tags"
  echo "-i, --image                   image to build or publish"
  echo "-c, --cuda-version            cuda version to build cuda11.3.1-ubuntu20.04|cuda11.8.0-ubuntu20.04|all (default: all)"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -r|--registry)
        CONTAINER_REGISTRY="$2"
        shift 2
        ;;
      -p|--publish)
        PUBLISH="$2"
        shift 2
        ;;
      -i|--image)
        IMAGE="$2"
        shift 2
        ;;
      -c|--cuda-version)
        CUDA_VERSION="$2"
        CUDA_VERSION_PROVIDED=true
        shift 2
        ;;
      *)
        echo "Invalid argument: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

if [ -z "$CONTAINER_REGISTRY" ]
then
  echo "Container registry is not set!. Using docker hub registry"
  CONTAINER_REG_OWNER=ghcr.io/a2s-institute/docker-stacks
else
  echo "Using $CONTAINER_REGISTRY registry"
  OWNER=a2s-institute/docker-stacks
  CONTAINER_REG_OWNER=$CONTAINER_REGISTRY/$OWNER
fi

echo "Container registry/owner = $CONTAINER_REG_OWNER"

function build_and_publish_single_image {
  IMAGE_DIR=$1
  IMAGE_TAG=$2
  PORT=$3

  if ! docker build -t $IMAGE_TAG $IMAGE_DIR; then
    echo "Docker build failed $IMAGE_TAG"
    exit 1
  fi

  if docker run -it --rm -d -p $PORT:$PORT $IMAGE_TAG;
  then
    echo "$IMAGE_TAG is running";
  else
    echo "Failed to run $IMAGE_TAG" && exit 1;
  fi

  if [ "$PUBLISH" = "all" ]
  then
    echo "Pushing $IMAGE_TAG"
    docker push $IMAGE_TAG
  else
    echo "None is published"
  fi
}

function build_base_image {
  # Generate base dockerfile and images
  cd $IMAGE
  bash generate_dockerfile.sh
  
  BASE_PORT=7070
  CUDA_VERSION_DIR=$1
  IMAGE_DIR=.build/$CUDA_VERSION_DIR

  IMAGE_TAG=$CONTAINER_REG_OWNER/$IMAGE:$CUDA_VERSION_DIR
  echo "Building base image $IMAGE_TAG"
  build_and_publish_single_image $IMAGE_DIR $IMAGE_TAG $BASE_PORT
  cd ..
}

function build_image {
  cd $IMAGE
  NB_PORT=8080
  CUDA_VERSION_DIR=$1
  IMAGE_DIR=$CUDA_VERSION_DIR

  IMAGE_TAG=$CONTAINER_REG_OWNER/$IMAGE:$IMAGE_DIR
  echo "Building image $IMAGE_TAG"
  build_and_publish_single_image $IMAGE_DIR $IMAGE_TAG $NB_PORT

  cd ..
}

function main {
  if [ "$IMAGE" = "base-gpu-notebook" ]
  then
    echo "Building $IMAGE $CUDA_VERSION"
    build_base_image $CUDA_VERSION
  elif [ "$IMAGE" = "gpu-notebook" ]
  then
    echo "Building $IMAGE $CUDA_VERSION"
    build_image $CUDA_VERSION
  else
    echo "Unrecognized $IMAGE and $CUDA_VERSION"
  fi
}

# build and push docker image
parse_args "$@"
echo "Building and publishing images"
main
