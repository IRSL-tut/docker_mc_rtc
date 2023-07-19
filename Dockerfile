# syntax=docker/dockerfile:1 
FROM ubuntu:20.04

ARG GITHUB_TOKEN
ARG REPOSITORY=IRSL-tut
ARG COMMIT_SHA=master
ENV REPOSITORY ${REPOSITORY}
ENV COMMIT_SHA ${COMMIT_SHA}

# https://qiita.com/haessal/items/0a83fe9fa1ac00ed5ee9
ENV DEBCONF_NOWARNINGS=yes
# https://qiita.com/yagince/items/deba267f789604643bab
ENV DEBIAN_FRONTEND=noninteractive
# https://qiita.com/jacob_327/items/e99ca1cf8167d4c1486d
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# https://stackoverflow.com/a/25423366
SHELL ["/bin/bash", "-c"]

# Install basic packages
RUN apt-get update -qq
RUN apt-get install -y sudo aptitude build-essential lsb-release wget gnupg2 curl emacs
RUN aptitude update -q

# Install ROS
ENV ROS_DISTRO noetic
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN wget http://packages.ros.org/ros.key -O - | apt-key add -
RUN apt-get update -qq
RUN apt-get install -y ros-${ROS_DISTRO}-ros-base python3-catkin-tools python3-rosdep python3-wstool python3-rosinstall python3-rosinstall-generator doxygen graphviz
# Install rospackage for mc_rtc
RUN curl -1sLf 'https://dl.cloudsmith.io/public/mc-rtc/stable/setup.deb.sh' | bash
RUN apt-get install -y ros-${ROS_DISTRO}-mc-rtc-plugin ros-${ROS_DISTRO}-mc-rtc-rviz-panel

# Setup catkin workspace
ENV HOME /root
RUN mkdir -p ${HOME}/catkin_ws/src
WORKDIR ${HOME}/catkin_ws

# Setup CMake latest version (3.23.3)
WORKDIR ${HOME}
RUN apt install build-essential checkinstall zlib1g-dev libssl-dev -y
RUN wget https://github.com/Kitware/CMake/releases/download/v3.23.3/cmake-3.23.3.tar.gz
RUN tar -zxvf cmake-3.23.3.tar.gz
WORKDIR ${HOME}/cmake-3.23.3
RUN ./bootstrap
RUN make
RUN make install
RUN hash -r

# Setup Github SSH
WORKDIR $HOME
RUN apt update
RUN apt install -y \
    git \
    openssh-server
RUN mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git config --global url.git@github.com:.insteadOf https://github.com/

# Setup mc_rtc
RUN git config --global user.email "tako.taro.tf@tut.jp"
RUN git config --global user.name "tabinohito"
RUN echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
RUN echo 'export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH' >> ~/.bashrc
RUN echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
RUN echo 'export PYTHONPATH=/usr/local/lib/python3.8/dist-packages:$PYTHONPATH' >> ~/.bashrc
RUN echo 'export ROS_PARALLEL_JOBS="-j8 -l8"' >> ~/.bashrc
RUN echo 'source /opt/ros/${ROS_DISTRO}/setup.bash' >> ~/.bashrc
RUN echo 'source /root/workspace/src/catkin_ws/devel/setup.bash' >> ~/.bashrc
RUN apt install -y pip 
RUN mkdir -p ${HOME}/workspace
WORKDIR ${HOME}/workspace
RUN --mount=type=ssh \
    git clone git@github.com:tabinohito/mc-rtc-superbuild.git
RUN  /bin/bash -c "cmake -S mc-rtc-superbuild -B mc-rtc-superbuild/build -DSOURCE_DESTINATION=${HOME}/workspace/src -DBUILD_DESTINATION=${HOME}/workspace/build"
# RUN --mount=type=ssh \
#     /bin/bash -c \
#     "source /opt/ros/${ROS_DISTRO}/setup.bash  && \
#     cmake --build mc-rtc-superbuild/build --target install"

# # To handle CI triggered by Pull Request, COMMIT_SHA must be specified in the git fetch argument,
# # but since wstool does not support it, execute the git commands directly instead.
# # RUN wstool set -t src BaselineWalkingController https://github.com/${REPOSITORY}/BaselineWalkingController --git -y -v ${COMMIT_SHA}
# RUN mkdir -p src/isri-aist/BaselineWalkingController && \
#     cd src/isri-aist/BaselineWalkingController && \
#     git init && \
#     git remote add origin https://github.com/${REPOSITORY}/BaselineWalkingController && \
#     git fetch origin ${COMMIT_SHA} && \
#     git checkout ${COMMIT_SHA} && \
#     git submodule update --init --recursive
# RUN wstool merge -t src src/isri-aist/BaselineWalkingController/depends.rosinstall
# RUN wstool update -t src

# # Rosdep install
# RUN rosdep init
# RUN rosdep update
# RUN source /opt/ros/${ROS_DISTRO}/setup.bash && rosdep install -y -r --from-paths src --ignore-src

# # Catkin build
# RUN source /opt/ros/${ROS_DISTRO}/setup.bash && catkin build baseline_footstep_planner -DCMAKE_BUILD_TYPE=RelWithDebInfo
# RUN source ${HOME}/catkin_ws/devel/setup.bash && catkin build baseline_walking_controller -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_QLD=ON
# RUN echo "source ${HOME}/catkin_ws/devel/setup.bash" >> ${HOME}/.bashrc