python build-locally.py linux64 > >(tee build-recipes.out) 2> >(tee build-recipes.err >&2)


anaconda login

anaconda upload build_artifacts/linux-64/*.conda
