#!/bin/bash

# cert.sh: makes ssl files for apache.

(
    # install openssl 1.1.
    installed=false;
    if [ -z "$( openssl version | grep -E 'OpenSSL [1-9]\.[1-9]' )" ]; then
        echo "cert.sh: OpenSSL 1.1+ is required. insall/upgrade OpenSSL (yes/no)?";
        tls='';
        while [ -z "$tls" ]; do
            if [ -z "$homebrew" ]; then
                read REPLY;
                tls=$( echo $REPLY );
            fi
            if [ "$tls" = "yes" ] && [ ! -z "$( command -v brew )" ]; then
                json=$( curl 'https://formulae.brew.sh/api/formula/openssl.json' );
                version=$( sed 's/^.\{1,\}versioned_formulae.\{4\}openssl@\([0-9]\.[0-9]\).\{1,\}$/\1/g' <<< $json );
                echo "cert.sh: installing OpenSSL $version...";
                brew update;
                brew doctor;
                brew install openssl@$version;
                brew link --overwrite openssl@$version;
                if [ ! -z "$( openssl version | grep -E 'OpenSSL [1-9]\.[1-9]' )" ]; then
                    echo "cert.sh: enter the name of your bash profile file:";
                    profile='';
                    home=$( ( cd ~ && pwd ) );
                    while [ -z "$profile" ]; do
                        read REPLY;
                        profile=$( echo $REPLY );
                        profile=$( basename $profile );
                        profile="$home/$profile";
                        if [ ! -f $profile ]; then
                            profile='';
                            echo "cert.sh: error! unable to find profile. please try agian.";
                        fi
                    done
                    # add openssl@1.1 to PATH.
                    echo 'export PATH="/usr/local/opt/openssl@1.1/bin:$PATH"' >> $profile;
                    installed=true;
                else
                    installed=false;
                    echo "cert.sh: error! OpenSSL 1.1 failed to install.";
                fi
            elif [ "$tls" = "yes" ] && [ -z "$( command -v brew )" ]; then
                installed=false;
                echo "cert.sh: homebrew not found, please install it.";
                echo "cert.sh: OpenSSL not installed.";
            elif [ "$tls" = "no" ]; then
                installed=false;
                echo "cert.sh: OpenSSL not installed.";
            else
                tls='';
                echo "cert.sh: please try again.";
            fi
        done
    else
        installed=true;
    fi
    if [ "$installed" = true ]; then
        # collect csr fields.
        echo "cert.sh: enter the following csr fields:";
        csr='';
        while [ -z "$csr" ]; do
            echo "cert.sh: enter common name (e.g. foo.com):";
            read REPLY;
            hostname=$( echo $REPLY );
            echo "cert.sh: enter two letter country code (ex: US):";
            read REPLY;
            c=$( echo $REPLY );
            echo "cert.sh: enter state (ex: CA):";
            read REPLY;
            st=$( echo $REPLY );
            echo "cert.sh: enter locality (ex: San Francisco):";
            read REPLY;
            l=$( echo $REPLY );
            echo "cert.sh: enter organization (ex: Acme Inc):";
            read REPLY;
            o=$( echo $REPLY );
            echo "confirm (yes/no): [CN=$hostname][C=$c][ST=$st][L=$l][O=$o]";
            read REPLY;
            csr=$( echo $REPLY );
            if [ -z "$hostname" ] || [ -z "$c" ] || [ -z "$st" ] || [ -z "$l" ] || [ -z "$o" ]; then
                csr='';
                echo "cert.sh: error! one or more fields are blank.";
            elif [ "$csr" != "yes" ]; then
                csr='';
                echo "cert.sh: please try again.";
            fi
        done
        # generate private key.
        mkdir -p ssl;
        openssl genrsa -out ssl/site.key 2048 2> /dev/null;
        # make temporary /etc/ssl/openssl.cnf file.
        cat /etc/ssl/openssl.cnf > ssl/tmp_open_ssl.cnf;
        echo '[ SAN ]' >> ssl/tmp_open_ssl.cnf;
        echo "subjectAltName=DNS:$hostname" >> ssl/tmp_open_ssl.cnf;
        # make csr.
        openssl req \
        -new \
        -key ssl/site.key \
        -out ssl/site.csr \
        -subj "/C=$c/ST=$st/L=$l/O=$o/CN=$hostname" \
        -reqexts SAN \
        -addext "subjectAltName = DNS:$hostname" \
        -config ssl/tmp_open_ssl.cnf 2> /dev/null;
        # make crt.
        openssl req \
        -x509 \
        -nodes \
        -days 3650 \
        -key ssl/site.key \
        -in ssl/site.csr \
        -out ssl/site.crt \
        -reqexts SAN \
        -addext "subjectAltName = DNS:$hostname" \
        -config ssl/tmp_open_ssl.cnf 2> /dev/null;
        rm ssl/tmp_open_ssl.cnf;
        if [ -f ssl/site.key ] && [ -f ssl/site.csr ] && [ ssl/site.crt ]; then
            echo "success! ssl folder made.";
            echo "1. put site.crt into 'System' keychain.";
            echo "2. install site.crt and site.key on your server.";
            echo "3. restart apache and browser.";
        else
            rm -rf ssl;
            echo "cert.sh: error! unable to make ssl files.";
        fi
    else
        echo "cert.sh: exiting...";
    fi
)