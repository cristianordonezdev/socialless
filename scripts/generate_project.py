#!/usr/bin/env python3
"""Generate the small native project deterministically, without package dependencies."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def oid(key):
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()


def obj(key, isa, **fields):
    ident = oid(key)
    objects[ident] = dict(isa=isa, **fields)
    return ident


def encode(value, indent=0):
    if isinstance(value, dict):
        return "{\n" + "\n".join("\t" * (indent + 1) + json.dumps(str(k)) + " = " + encode(v, indent + 1) + ";" for k, v in value.items()) + "\n" + "\t" * indent + "}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(v, indent) for v in value) + ")"
    return json.dumps(str(value))


def configurations(key, base):
    configs = []
    for mode in ("Debug", "Release"):
        settings = dict(base)
        settings.update(SWIFT_OPTIMIZATION_LEVEL="-Onone" if mode == "Debug" else "-O")
        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG" if mode == "Debug" else ""
        configs.append(obj(key + mode, "XCBuildConfiguration", name=mode, buildSettings=settings))
    return obj(key + "configs", "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


products, groups, targets = [], [], []
for name, kind, ext, product_type in (
    ("SocialLess", "application", "app", "com.apple.product-type.application"),
    ("SocialLessTests", "bundle", "xctest", "com.apple.product-type.bundle.unit-test"),
    ("SocialLessUITests", "bundle", "xctest", "com.apple.product-type.bundle.ui-testing"),
):
    refs, sources, resources = [], [], []
    for file in sorted((ROOT / name).rglob("*")):
        if not file.is_file() or ".xcassets/" in str(file):
            continue
        if file.suffix not in (".swift", ".html", ".json", ".xcprivacy"):
            continue
        rel = str(file.relative_to(ROOT))
        file_type = {".swift": "sourcecode.swift", ".html": "text.html", ".json": "text.json", ".xcprivacy": "text.xml"}[file.suffix]
        ref = obj(rel, "PBXFileReference", lastKnownFileType=file_type, path=rel, sourceTree="SOURCE_ROOT")
        refs.append(ref)
        build = obj(rel + "build", "PBXBuildFile", fileRef=ref)
        (sources if file.suffix == ".swift" else resources).append(build)
    for file in sorted((ROOT / name).rglob("*.xcassets")):
        rel = str(file.relative_to(ROOT))
        ref = obj(rel, "PBXFileReference", lastKnownFileType="folder.assetcatalog", path=rel, sourceTree="SOURCE_ROOT")
        refs.append(ref)
        resources.append(obj(rel + "build", "PBXBuildFile", fileRef=ref))
    groups.append(obj(name + "group", "PBXGroup", name=name, children=refs, sourceTree="<group>"))
    product = obj(name + "product", "PBXFileReference", explicitFileType="wrapper.application" if ext == "app" else "wrapper.cfbundle", path=name + "." + ext, sourceTree="BUILT_PRODUCTS_DIR")
    products.append(product)
    phases = [obj(name + "sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=sources, runOnlyForDeploymentPostprocessing=0), obj(name + "frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0), obj(name + "resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=resources, runOnlyForDeploymentPostprocessing=0)]
    settings = dict(PRODUCT_BUNDLE_IDENTIFIER="com.socialless." + name, PRODUCT_NAME="$(TARGET_NAME)", GENERATE_INFOPLIST_FILE="YES", CODE_SIGN_STYLE="Automatic", TARGETED_DEVICE_FAMILY="1", SWIFT_EMIT_LOC_STRINGS="YES")
    deps = []
    if name == "SocialLess":
        settings.update(INFOPLIST_KEY_CFBundleDisplayName="SocialLess", INFOPLIST_KEY_UILaunchScreen_Generation="YES", INFOPLIST_KEY_UIApplicationSceneManifest_Generation="YES", INFOPLIST_KEY_UISupportedInterfaceOrientations="UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight", INFOPLIST_KEY_UIFileSharingEnabled="NO", INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace="NO", MARKETING_VERSION="0.1.0", CURRENT_PROJECT_VERSION="1", ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME="AccentColor")
        settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
    else:
        proxy = obj(name + "proxy", "PBXContainerItemProxy", containerPortal=oid("project"), proxyType=1, remoteGlobalIDString=oid("SocialLesstarget"), remoteInfo="SocialLess")
        deps = [obj(name + "dependency", "PBXTargetDependency", target=oid("SocialLesstarget"), targetProxy=proxy)]
        if name == "SocialLessTests":
            settings.update(TEST_HOST="$(BUILT_PRODUCTS_DIR)/SocialLess.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/SocialLess", BUNDLE_LOADER="$(TEST_HOST)")
        else:
            settings.update(TEST_TARGET_NAME="SocialLess")
    targets.append(obj(name + "target", "PBXNativeTarget", buildConfigurationList=configurations(name, settings), buildPhases=phases, buildRules=[], dependencies=deps, name=name, productName=name, productReference=product, productType=product_type))

product_group = obj("products", "PBXGroup", name="Products", children=products, sourceTree="<group>")
main_group = obj("main", "PBXGroup", children=groups + [product_group], sourceTree="<group>")
project = obj("project", "PBXProject", attributes={"LastUpgradeCheck": "2700", "BuildIndependentTargetsInParallel": "YES"}, buildConfigurationList=configurations("project", dict(SWIFT_VERSION="5.0", IPHONEOS_DEPLOYMENT_TARGET="17.0", SDKROOT="iphoneos", SUPPORTED_PLATFORMS="iphoneos iphonesimulator", CLANG_ENABLE_MODULES="YES", ENABLE_TESTABILITY="YES", SWIFT_STRICT_CONCURRENCY="complete", DEBUG_INFORMATION_FORMAT="dwarf-with-dsym")), compatibilityVersion="Xcode 14.0", developmentRegion="en", knownRegions=["en", "Base"], mainGroup=main_group, productRefGroup=product_group, projectDirPath="", projectRoot="", targets=targets)
project_dir = ROOT / "SocialLess.xcodeproj"
project_dir.mkdir(exist_ok=True)
(project_dir / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project)) + "\n")
schemes = project_dir / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)


def reference(name, ext):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{oid(name + "target")}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:SocialLess.xcodeproj"/>'


(schemes / "SocialLess.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference("SocialLess", "app")}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
    <TestableReference skipped="NO">{reference("SocialLessTests", "xctest")}</TestableReference>
    <TestableReference skipped="NO">{reference("SocialLessUITests", "xctest")}</TestableReference>
  </Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("SocialLess", "app")}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("SocialLess", "app")}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print("Generated SocialLess.xcodeproj (app, unit tests, UI tests).")
