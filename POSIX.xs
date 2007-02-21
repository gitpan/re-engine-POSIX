#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <assert.h>
#include <regex.h>

#define SAVEPVN(p,n) ((p) ? savepvn(p,n) : NULL)

START_EXTERN_C

EXTERN_C const regexp_engine engine_posix;

END_EXTERN_C

int
perl2posixflags(int intflags)
{
    int retflags = 0;

    /* Comptute the POSIX flags from perl's internal flags, REG_NOSUB
     * has no meaning in Perl world */
    
    /* /x */
    if (intflags & PMf_EXTENDED)
        retflags |= REG_EXTENDED;

    /* /i */
    if (intflags & PMf_FOLD)
        retflags |= REG_ICASE;

    /* /m */
    if (intflags & PMf_MULTILINE)
        retflags |= REG_NEWLINE;

    return retflags;
}

/* From *info* (libc) 10.3.6 POSIX Regexp Matching Cleanup */
char *get_regerror (int errcode, regex_t *compiled)
{
    size_t length = regerror (errcode, compiled, NULL, 0);
    char *buffer = malloc (length);
    (void) regerror (errcode, compiled, buffer, length);
    return buffer;
}

regexp *
POSIX_comp(pTHX_ char *exp, char *xend, PMOP *pm)
{
    /* Perl regexp stuff */
    register regexp  *r;

    /* pregcomp vars */
    register regex_t *re;
    int cflags = 0;
    int err;
    char *err_msg;

    /* regex structure for perl */
    Newxz(r,1,regexp);

    /* have the regex handled by the POSIX engine */
    r->engine = &engine_posix;

    /* don't destroy us! */
    r->refcnt = 1;

    /* Preserve a copy of the original pattern */
    r->prelen = xend - exp;
    r->precomp = SAVEPVN(exp, r->prelen);

    /* Store the flags as perl expects them */
    r->extflags = pm->op_pmflags & RXf_PMf_COMPILETIME;

    Newxz(re, 1, regex_t);

    /* Save our re */
    r->pprivate = re;

    cflags = perl2posixflags(pm->op_pmflags);
    //fprintf(stderr,"precomp = %s\n", r->precomp);
    if ((err = regcomp(re, r->precomp, cflags)) != 0) {
        err_msg = get_regerror(err, re);
        free(err_msg);
        regfree(re);
        croak("error compiling %s: %s", r->precomp, err_msg);
    }

    /* Tell perl how many match vars we have and allocate space for
     * them, at least one is always allocated for $&
     */
    r->nparens = (U32)re->re_nsub; /* from size_t */
    Newxz(r->startp, 1+(U32)re->re_nsub, I32);
    Newxz(r->endp, 1+(U32)re->re_nsub, I32);

    /* return the regexp structure to perl */
    return r;
}

I32
POSIX_exec(pTHX_ register regexp *r, char *stringarg, register char *strend,
                  char *strbeg, I32 minend, SV *sv, void *data, U32 flags)
{
    /* pregcomp vars */
    register regex_t *re;
    regmatch_t *matches;
    size_t parens;
    int err;
    char *err_msg;
    int i, e, s;

    re = r->pprivate;
    parens = (size_t)r->nparens + 1;

    Newxz(matches, parens, regmatch_t);
    if ((err = regexec(re, stringarg, parens, matches, 0)) != 0) {
        assert(err == REG_NOMATCH);
        Safefree(matches);
        return 0;
    }

    if (err != 0) {
        if (err == REG_NOMATCH) {
            /* We didn't match */
            Safefree(matches);
            return 0;
        } else {
            /* This should only be REG_ESPACE */
            err_msg = get_regerror(err, re);
            free(err_msg);
            regfree(re);
            Safefree(matches);
            croak("error executing %s: %s", r->precomp, err_msg);
        }
    }

    r->sublen = strend-strbeg;
    r->subbeg = savepvn(strbeg,r->sublen);

    for (i = 0; i < (r->nparens + 1); i++) {
        s = matches[i].rm_so;
        e = matches[i].rm_eo;

        if (s == -1 || e == -1) {
            break;
        } else {
            r->startp[i] = s;
            r->endp[i] = e;
        }
    }

    Safefree(matches);
             
    /* known to have matched by this point (see error handling above */   
    return 1;
}

char *
POSIX_intuit(pTHX_ regexp *prog, SV *sv, char *strpos,
                     char *strend, U32 flags, re_scream_pos_data *data)
{
    return NULL;
}

SV *
POSIX_checkstr(pTHX_ regexp *prog)
{
    return NULL;
}

void
POSIX_free(pTHX_ struct regexp *r)
{
    regfree(r->pprivate);
}

void *
POSIX_dupe(pTHX_ const regexp *r, CLONE_PARAMS *param)
{
    return r->pprivate;
}

const regexp_engine engine_posix = {
        POSIX_comp,
        POSIX_exec,
        POSIX_intuit,
        POSIX_checkstr,
        POSIX_free,
        Perl_reg_numbered_buff_get,
        Perl_reg_named_buff_get,
#if defined(USE_ITHREADS)        
        POSIX_dupe,
#endif
};

MODULE = re::engine::POSIX	PACKAGE = re::engine::POSIX

void
get_posix_engine()
PPCODE:
    XPUSHs(sv_2mortal(newSViv(PTR2IV(&engine_posix))));
