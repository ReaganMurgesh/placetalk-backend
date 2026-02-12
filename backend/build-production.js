// Production build script - builds with relaxed type checking
console.log('🔨 Building for production...');
const { execSync } = require('child_process');

try {
    // Build with noEmitOnError=false to allow build despite type errors
    execSync('tsc --noEmitOnError false', { stdio: 'inherit', cwd: __dirname });
    console.log('✅ Build completed successfully');
    process.exit(0);
} catch (error) {
    console.error('❌ Build failed');
    process.exit(1);
}
