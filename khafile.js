let project = new Project('Khaos');
project.addSources('Sources');
project.addShaders('Sources/Shaders/**');
project.addAssets('Assets/**');
resolve(project);
