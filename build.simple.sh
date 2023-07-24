set -e

CURID=$$

echo "######## STAGE1 ########"
docker build . --progress=plain -f Dockerfile.simple -t mc_rtc:build0

echo "######## STAGE2 ########"
docker run --name mc_rtc_build1_${CURID} mc_rtc:build0 \
       -- bash -c 'cmake -S mc-rtc-superbuild -B mc-rtc-superbuild/build -DSOURCE_DESTINATION=${BUILD_ROOT}/workspace/src -DBUILD_DESTINATION=${BUILD_ROOT}/workspace/build; cmake --build mc-rtc-superbuild/build --config RelWithDebInfo'

echo "######## STAGE3 ########"
docker commit mc_rtc_build1_${CURID} mc_rtc:build1

echo "######## STAGE4 ########"
docker run --name mc_rtc_build2_${CURID} -v $(pwd):/userdir mc_rtc:build1 \
       -- bash -c 'cp -r /userdir/superbuild-choreonoid mc-rtc-superbuild/extensions && cp /userdir/local.cmake mc-rtc-superbuild/extensions && source ~/.bashrc;  cmake -S mc-rtc-superbuild -B mc-rtc-superbuild/build -DSOURCE_DESTINATION=${BUILD_ROOT}/workspace/src -DBUILD_DESTINATION=${BUILD_ROOT}/workspace/build && cmake --build mc-rtc-superbuild/build --config RelWithDebInfo --target clone && cmake --build mc-rtc-superbuild/build --config RelWithDebInfo'
## cp -r /userdir/superbuild-choreonoid mc-rtc-superbuild/extensions;
## ( source ~/.bashrc; cmake -S mc-rtc-superbuild -B mc-rtc-superbuild/build -DSOURCE_DESTINATION=${BUILD_ROOT}/workspace/src -DBUILD_DESTINATION=${BUILD_ROOT}/workspace/build )
## ( source ~/.bashrc; cmake --build mc-rtc-superbuild/build --config RelWithDebInfo --target clone )
## ( source ~/.bashrc; cmake --build mc-rtc-superbuild/build --config RelWithDebInfo )

echo "######## STAGE5 ########"
docker commit mc_rtc_build2_${CURID} mc_rtc:build2

echo "######## STAGE6 ########"
## add rtshell
docker build . --progress=plain -f Dockerfile.add_rtshell --build-arg BASE_IMAGE=mc_rtc:build2 -t mc_rtc:cnoid
