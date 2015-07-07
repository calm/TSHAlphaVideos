#ifndef AlphaVideo_ShaderUtilities_h
#define AlphaVideo_ShaderUtilities_h
    
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

GLint openGlCompileShader(GLenum target, GLsizei count, const GLchar **sources, GLuint *shader);
GLint openGlLinkProgram(GLuint program);
GLint openGlValidateProgram(GLuint program);
GLint openGlGetUniformLocation(GLuint program, const GLchar *name);

GLint openGlCreateProgram(const GLchar *vertSource, const GLchar *fragSource,
                        GLsizei attribNameCt, const GLchar **attribNames, 
                        const GLint *attribLocations,
                        GLsizei uniformNameCt, const GLchar **uniformNames,
                        GLint *uniformLocations,
                        GLuint *program);

#endif
