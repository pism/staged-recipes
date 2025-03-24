python build-locally.py linux64 > >(tee build-and-push-recipes.out) 2> >(tee build-and-push-recipes.err >&2)


anaconda login

anaconda upload build_artifacts/linux-64/*.conda
